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
        @logger = nil
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

      def clear_all_handlers
        @event_emitter.clear_all_handlers
      end

      def set_provider(provider, domain: nil)
        @provider_mutex.synchronize do
          set_provider_internal(provider, domain:)
        end
      end

      def set_provider_and_wait(provider, domain: nil, timeout: 30)
        completion_queue = Queue.new

        ready_handler = lambda do |event_details|
          if event_details[:provider] == provider
            completion_queue << {status: :ready}
          end
        end

        error_handler = lambda do |event_details|
          if event_details[:provider] == provider
            completion_queue << {
              status: :error,
              message: event_details[:message] || "an unspecified error occurred",
              error_code: event_details[:error_code]
            }
          end
        end

        add_handler(ProviderEvent::PROVIDER_READY, ready_handler)
        add_handler(ProviderEvent::PROVIDER_ERROR, error_handler)

        # Lock only while mutating shared state
        @provider_mutex.synchronize do
          set_provider_internal(provider, domain:)
        end

        begin
          # Wait for initialization to complete, outside the main provider mutex
          Timeout.timeout(timeout) do
            result = completion_queue.pop

            if result[:status] == :error
              error_code = result[:error_code] || Provider::ErrorCode::PROVIDER_FATAL
              message = result[:message]
              raise ProviderInitializationError.new(
                "Provider #{provider.class.name} initialization failed: #{message}",
                provider:,
                error_code:,
                original_error: nil  # Exceptions not included in events
              )
            end
          end
        rescue Timeout::Error => e
          raise ProviderInitializationError.new(
            "Provider #{provider.class.name} initialization timed out after #{timeout} seconds",
            provider:,
            original_error: e
          )
        ensure
          remove_handler(ProviderEvent::PROVIDER_READY, ready_handler)
          remove_handler(ProviderEvent::PROVIDER_ERROR, error_handler)
        end
      end

      private

      def set_provider_internal(provider, domain: nil)
        old_provider = @providers[domain]

        begin
          old_provider.shutdown if old_provider.respond_to?(:shutdown)
        rescue => e
          @logger&.warn("Error shutting down previous provider #{old_provider&.class&.name || "unknown"}: #{e.message}")
        end

        # Remove old provider state to prevent memory leaks
        @provider_state_registry.remove_provider(old_provider)

        new_providers = @providers.dup
        new_providers[domain] = provider
        @providers = new_providers

        @provider_state_registry.set_initial_state(provider)

        provider.attach(ProviderEventDispatcher.new(self)) if provider.is_a?(Provider::EventHandler)

        # Capture evaluation context to prevent race condition
        context_for_init = @evaluation_context

        Thread.new do
          if provider.respond_to?(:init)
            init_method = provider.method(:init)
            if init_method.parameters.empty?
              provider.init
            else
              provider.init(context_for_init)
            end
          end

          unless provider.is_a?(Provider::EventHandler)
            dispatch_provider_event(provider, ProviderEvent::PROVIDER_READY)
          end
        rescue => e
          dispatch_provider_event(provider, ProviderEvent::PROVIDER_ERROR,
            error_code: Provider::ErrorCode::PROVIDER_FATAL,
            message: e.message)
        end
      end

      def dispatch_provider_event(provider, event_type, details = {})
        @provider_state_registry.update_state_from_event(provider, event_type, details)

        # Trigger event handlers
        event_details = {
          provider:,
          provider_name: provider.class.name
        }.merge(details)

        @event_emitter.trigger_event(event_type, event_details)
      end

      def provider_state(provider)
        @provider_state_registry.get_state(provider)
      end

      private

      def handler_count(event_type)
        @event_emitter.handler_count(event_type)
      end

      def total_handler_count
        ProviderEvent::ALL_EVENTS.sum { |event_type| handler_count(event_type) }
      end

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
