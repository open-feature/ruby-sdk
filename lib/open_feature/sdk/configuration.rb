# frozen_string_literal: true

require "timeout"
require_relative "api"
require_relative "provider_initialization_error"
require_relative "event_emitter"
require_relative "provider_event"
require_relative "provider_state_registry"
require_relative "provider/event_handler"

module OpenFeature
  module SDK
    # Represents the configuration object for the global API where <tt>Provider</tt>, <tt>Hook</tt>,
    # and <tt>EvaluationContext</tt> are configured.
    # This class is not meant to be interacted with directly but instead through the <tt>OpenFeature::SDK.configure</tt>
    # method
    class Configuration
      extend Forwardable

      attr_accessor :evaluation_context, :hooks
      attr_reader :logger

      def initialize
        @hooks = []
        @providers = {}
        @provider_mutex = Mutex.new
        @logger = nil  # Users can set a logger if needed
        @event_emitter = EventEmitter.new(@logger)
        @provider_state_registry = ProviderStateRegistry.new
      end

      def provider(domain: nil)
        @providers[domain] || @providers[nil]
      end

      def logger=(new_logger)
        @logger = new_logger
        @event_emitter.logger = new_logger if @event_emitter
      end

      def add_handler(event_type, handler)
        @event_emitter.add_handler(event_type, handler)
      end

      def remove_handler(event_type, handler)
        @event_emitter.remove_handler(event_type, handler)
      end

      def set_provider(provider, domain: nil)
        @provider_mutex.synchronize do
          old_provider = @providers[domain]
          
          begin
            old_provider.shutdown if old_provider.respond_to?(:shutdown)
          rescue StandardError => e
            @logger&.warn("Error shutting down previous provider #{old_provider.class.name}: #{e.message}")
          end
          
          new_providers = @providers.dup
          new_providers[domain] = provider
          @providers = new_providers
          
          @provider_state_registry.set_initial_state(provider)
          
          if provider.is_a?(Provider::EventHandler)
            provider.attach(ProviderEventDispatcher.new(self))
          end
          
          Thread.new do
            begin
              if provider.respond_to?(:init)
                if provider.method(:init).arity == 1
                  provider.init(@evaluation_context)
                else
                  provider.init
                end
              end
              
              unless provider.is_a?(Provider::EventHandler)
                dispatch_provider_event(provider, ProviderEvent::PROVIDER_READY)
              end
            rescue StandardError => e
              dispatch_provider_event(provider, ProviderEvent::PROVIDER_ERROR, 
                                    error_code: Provider::ErrorCode::PROVIDER_FATAL,
                                    message: e.message)
            end
          end
        end
      end

      def set_provider_and_wait(provider, domain: nil, timeout: 30)
        old_provider = nil
        @provider_mutex.synchronize { old_provider = @providers[domain] }
        
        completion_queue = Queue.new
        
        ready_handler = lambda do |event_details|
          if event_details[:provider] == provider
            completion_queue << { status: :ready }
          end
        end
        
        error_handler = lambda do |event_details|
          if event_details[:provider] == provider
            completion_queue << { 
              status: :error, 
              message: event_details[:message] || "Provider initialization failed",
              error_code: event_details[:error_code]
            }
          end
        end
        
        add_handler(ProviderEvent::PROVIDER_READY, ready_handler)
        add_handler(ProviderEvent::PROVIDER_ERROR, error_handler)
        
        begin
          set_provider(provider, domain: domain)
          
          Timeout.timeout(timeout) do
            result = completion_queue.pop
            
            if result[:status] == :error
              revert_provider_if_current(domain, provider, old_provider)
              
              error_code = result[:error_code] || Provider::ErrorCode::PROVIDER_FATAL
              message = result[:message]
              raise ProviderInitializationError.new(
                "Provider initialization failed: #{message}",
                provider: provider,
                error_code: error_code,
                original_error: ProviderInitializationFailure.new(message, error_code)
              )
            end
          end
        rescue Timeout::Error => e
          revert_provider_if_current(domain, provider, old_provider)
          
          raise ProviderInitializationError.new(
            "Provider initialization timed out after #{timeout} seconds",
            provider: provider,
            original_error: e
          )
        ensure
          remove_handler(ProviderEvent::PROVIDER_READY, ready_handler)
          remove_handler(ProviderEvent::PROVIDER_ERROR, error_handler)
        end
      end

      private

      def revert_provider_if_current(domain, provider, old_provider)
        @provider_mutex.synchronize do
          if @providers[domain] == provider
            new_providers = @providers.dup
            new_providers[domain] = old_provider
            @providers = new_providers
          end
        end
      end

      def dispatch_provider_event(provider, event_type, details = {})
        @provider_state_registry.update_state_from_event(provider, event_type, details)
        
        # Trigger event handlers
        event_details = {
          provider: provider,
          provider_name: provider.class.name
        }.merge(details)
        
        @event_emitter.trigger_event(event_type, event_details)
      end

      # Private inner class for dispatching provider events
      class ProviderEventDispatcher
        def initialize(config)
          @config = config
        end

        def dispatch_event(provider, event_type, details)
          @config.send(:dispatch_provider_event, provider, event_type, details)
        end
      end
    end
  end
end
