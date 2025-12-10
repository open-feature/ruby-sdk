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

      def initialize
        @hooks = []
        @providers = {}
        @provider_mutex = Mutex.new
        @event_emitter = EventEmitter.new
        @provider_state_registry = ProviderStateRegistry.new
      end

      def provider(domain: nil)
        @providers[domain] || @providers[nil]
      end

      # Add an event handler for provider lifecycle events
      #
      # @param event_type [String] the event type (e.g., ProviderEvent::PROVIDER_READY)
      # @param handler [#call] the handler to call when the event occurs
      def add_handler(event_type, handler)
        @event_emitter.add_handler(event_type, handler)
      end

      # Remove an event handler
      #
      # @param event_type [String] the event type
      # @param handler [#call] the handler to remove
      def remove_handler(event_type, handler)
        @event_emitter.remove_handler(event_type, handler)
      end

      # When switching providers, there are a few lifecycle methods that need to be taken care of.
      #   1. If a provider is already set, we need to call `shutdown` on it.
      #   2. Set the new provider immediately (non-blocking)
      #   3. Initialize the provider asynchronously in a background thread
      #   4. Emit PROVIDER_READY or PROVIDER_ERROR events based on initialization result
      def set_provider(provider, domain: nil)
        @provider_mutex.synchronize do
          old_provider = @providers[domain]
          
          # Shutdown old provider (ignore errors)
          begin
            old_provider.shutdown if old_provider.respond_to?(:shutdown)
          rescue
            # Ignore shutdown errors
          end
          
          # Set new provider immediately (before initialization)
          new_providers = @providers.dup
          new_providers[domain] = provider
          @providers = new_providers
          
          # Set initial state
          @provider_state_registry.set_initial_state(provider)
          
          # Attach event dispatcher if provider supports events
          if provider.is_a?(Provider::EventHandler)
            # Create a dispatcher wrapper that forwards to our method
            config = self
            dispatcher = Object.new
            dispatcher.define_singleton_method(:dispatch_event) do |prov, event_type, details|
              config.send(:dispatch_provider_event, prov, event_type, details)
            end
            provider.attach(dispatcher)
          end
          
          # Initialize provider asynchronously
          Thread.new do
            begin
              # Pass the evaluation context if provider expects it
              if provider.respond_to?(:init)
                if provider.method(:init).arity == 1
                  provider.init(@evaluation_context)
                else
                  provider.init
                end
              end
              
              # If provider doesn't emit its own PROVIDER_READY, emit it
              unless provider.is_a?(Provider::EventHandler)
                dispatch_provider_event(provider, ProviderEvent::PROVIDER_READY)
              end
            rescue => e
              # Emit error event
              dispatch_provider_event(provider, ProviderEvent::PROVIDER_ERROR, 
                                    error_code: Provider::ErrorCode::PROVIDER_FATAL,
                                    message: e.message)
            end
          end
        end
      end

      # Sets a provider and waits for the initialization to complete or fail.
      # This method ensures the provider is ready (or in error state) before returning.
      #
      # @param provider [Object] the provider to set
      # @param domain [String, nil] the domain for the provider (optional)
      # @param timeout [Integer] maximum time to wait for initialization in seconds (default: 30)
      # @raise [ProviderInitializationError] if the provider fails to initialize or times out
      def set_provider_and_wait(provider, domain: nil, timeout: 30)
        # Store the old provider
        old_provider = nil
        @provider_mutex.synchronize { old_provider = @providers[domain] }
        
        # Use a queue to capture initialization result
        completion_queue = Queue.new
        
        # Set up event handlers to capture completion
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
        
        # Register handlers
        add_handler(ProviderEvent::PROVIDER_READY, ready_handler)
        add_handler(ProviderEvent::PROVIDER_ERROR, error_handler)
        
        begin
          # Start async initialization
          set_provider(provider, domain: domain)
          
          # Wait for completion with timeout
          Timeout.timeout(timeout) do
            result = completion_queue.pop
            
            if result[:status] == :error
              # Restore old provider on error
              @provider_mutex.synchronize do
                new_providers = @providers.dup
                new_providers[domain] = old_provider
                @providers = new_providers
              end
              
              raise ProviderInitializationError.new(
                "Provider initialization failed: #{result[:message]}",
                provider: provider,
                error_code: result[:error_code] || Provider::ErrorCode::PROVIDER_FATAL,
                original_error: StandardError.new(result[:message])
              )
            end
          end
        rescue Timeout::Error => e
          # Restore old provider on timeout
          @provider_mutex.synchronize do
            new_providers = @providers.dup
            new_providers[domain] = old_provider
            @providers = new_providers
          end
          
          raise ProviderInitializationError.new(
            "Provider initialization timed out after #{timeout} seconds",
            provider: provider,
            original_error: e
          )
        ensure
          # Clean up handlers
          remove_handler(ProviderEvent::PROVIDER_READY, ready_handler)
          remove_handler(ProviderEvent::PROVIDER_ERROR, error_handler)
        end
      end

      private

      # Dispatch a provider event to the event system
      #
      # @param provider [Object] the provider that triggered the event
      # @param event_type [String] the event type
      # @param details [Hash] additional event details
      def dispatch_provider_event(provider, event_type, details = {})
        # Update provider state based on event
        @provider_state_registry.update_state_from_event(provider, event_type, details)
        
        # Trigger event handlers
        event_details = {
          provider: provider,
          provider_name: provider.class.name
        }.merge(details)
        
        @event_emitter.trigger_event(event_type, event_details)
      end
    end
  end
end
