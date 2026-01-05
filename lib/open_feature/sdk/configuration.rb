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
        @client_handlers = {}
        @client_handlers_mutex = Mutex.new
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
        run_immediate_handler(event_type, handler, nil)
      end

      def remove_handler(event_type, handler)
        @event_emitter.remove_handler(event_type, handler)
      end

      def clear_all_handlers
        @event_emitter.clear_all_handlers
        @client_handlers_mutex.synchronize do
          @client_handlers.clear
        end
      end

      def add_client_handler(client, event_type, handler)
        @client_handlers_mutex.synchronize do
          @client_handlers[client] ||= Hash.new { |h, k| h[k] = [] }
          @client_handlers[client][event_type] << handler
        end

        run_immediate_handler(event_type, handler, client)
      end

      def remove_client_handler(client, event_type, handler)
        @client_handlers_mutex.synchronize do
          return unless @client_handlers[client]
          handlers = @client_handlers[client][event_type]
          handlers&.delete(handler)
        end
      end

      def set_provider(provider, domain: nil)
        @provider_mutex.synchronize do
          set_provider_internal(provider, domain: domain, wait_for_init: false)
        end
      end

      def set_provider_and_wait(provider, domain: nil)
        @provider_mutex.synchronize do
          set_provider_internal(provider, domain: domain, wait_for_init: true)
        end
      end

      private

      def set_provider_internal(provider, domain:, wait_for_init:)
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

        if wait_for_init
          init_provider(provider, context_for_init, raise_on_error: true)
        else
          Thread.new do
            init_provider(provider, context_for_init, raise_on_error: false)
          end
        end
      end

      def init_provider(provider, context, raise_on_error: false)
        if provider.respond_to?(:init)
          init_method = provider.method(:init)
          if init_method.parameters.empty?
            provider.init
          else
            provider.init(context)
          end
        end

        unless provider.is_a?(Provider::EventHandler)
          dispatch_provider_event(provider, ProviderEvent::PROVIDER_READY)
        end
      rescue => e
        dispatch_provider_event(provider, ProviderEvent::PROVIDER_ERROR,
          error_code: Provider::ErrorCode::PROVIDER_FATAL,
          message: e.message)

        if raise_on_error
          # Re-raise as ProviderInitializationError for synchronous callers
          raise ProviderInitializationError.new(
            "Provider #{provider.class.name} initialization failed: #{e.message}",
            provider:,
            error_code: Provider::ErrorCode::PROVIDER_FATAL,
            original_error: e
          )
        end
      end

      def dispatch_provider_event(provider, event_type, details = {})
        @provider_state_registry.update_state_from_event(provider, event_type, details)

        provider_name = extract_provider_name(provider)

        event_details = {
          provider_name: provider_name
        }.merge(details)

        run_handlers_for_provider(provider, event_type, event_details)
      end

      def provider_state(provider)
        @provider_state_registry.get_state(provider)
      end

      private

      def extract_provider_name(provider)
        provider.respond_to?(:metadata) ? provider.metadata.name : provider.class.name
      end

      def run_handlers_for_provider(provider, event_type, event_details)
        # Run global handlers (API-level, no domain filtering)
        @event_emitter.trigger_event(event_type, event_details)

        # Run client handlers (domain-scoped)
        @client_handlers_mutex.synchronize do
          @client_handlers.each do |client, handlers_by_event|
            # Check if this client should receive events from this provider
            client_provider = provider(domain: client.metadata.domain)
            next unless client_provider&.equal?(provider)

            # Trigger handlers for this client
            handlers = handlers_by_event[event_type]
            handlers.each do |handler|
              handler.call(event_details)
            rescue => e
              @logger&.error("Client event handler failed: #{e.message}")
            end
          end
        end
      end

      def run_immediate_handler(event_type, handler, client)
        status_to_event = {
          ProviderState::READY => ProviderEvent::PROVIDER_READY,
          ProviderState::ERROR => ProviderEvent::PROVIDER_ERROR,
          ProviderState::FATAL => ProviderEvent::PROVIDER_ERROR,
          ProviderState::STALE => ProviderEvent::PROVIDER_STALE
        }

        if client.nil?
          # API-level handler: check all providers
          @providers.each do |domain, provider|
            next unless provider

            provider_state = @provider_state_registry.get_state(provider)

            if event_type == status_to_event[provider_state]
              provider_name = extract_provider_name(provider)
              event_details = {provider_name: provider_name}

              begin
                handler.call(event_details)
              rescue => e
                @logger&.error("Immediate API event handler failed: #{e.message}")
              end
            end
          end
        else
          # Client-level handler: check specific provider only
          client_provider = provider(domain: client.metadata.domain)
          return unless client_provider

          provider_state = @provider_state_registry.get_state(client_provider)

          if event_type == status_to_event[provider_state]
            provider_name = extract_provider_name(client_provider)
            event_details = {provider_name: provider_name}

            begin
              handler.call(event_details)
            rescue => e
              @logger&.error("Immediate client event handler failed: #{e.message}")
            end
          end
        end
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
