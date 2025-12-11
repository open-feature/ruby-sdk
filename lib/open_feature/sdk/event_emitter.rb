# frozen_string_literal: true

require_relative 'provider_event'

module OpenFeature
  module SDK
    # Thread-safe pub-sub for provider events
    class EventEmitter
      attr_writer :logger

      def initialize(logger = nil)
        @handlers = {}
        @mutex = Mutex.new
        @logger = logger
        ProviderEvent::ALL_EVENTS.each { |event| @handlers[event] = [] }
      end

      def add_handler(event_type, handler)
        raise ArgumentError, "Invalid event type: #{event_type}" unless valid_event?(event_type)
        raise ArgumentError, "Handler must respond to call" unless handler.respond_to?(:call)

        @mutex.synchronize do
          @handlers[event_type] << handler
        end
      end

      def remove_handler(event_type, handler)
        return unless valid_event?(event_type)

        @mutex.synchronize do
          @handlers[event_type].delete(handler)
        end
      end

      def remove_all_handlers(event_type)
        return unless valid_event?(event_type)

        @mutex.synchronize do
          @handlers[event_type].clear
        end
      end

      def trigger_event(event_type, event_details = {})
        return unless valid_event?(event_type)

        handlers_to_call = nil
        @mutex.synchronize do
          handlers_to_call = @handlers[event_type].dup
        end

        # Call handlers outside of mutex to avoid deadlocks
        handlers_to_call.each do |handler|
          begin
            handler.call(event_details)
          rescue StandardError => e
            if @logger
              @logger.warn "Event handler failed for #{event_type}: #{e.message}"
            end
          end
        end
      end

      def handler_count(event_type)
        return 0 unless valid_event?(event_type)

        @mutex.synchronize do
          @handlers[event_type].size
        end
      end

      def clear_all_handlers
        @mutex.synchronize do
          @handlers.each_value(&:clear)
        end
      end

      private

      def valid_event?(event_type)
        ProviderEvent::ALL_EVENTS.include?(event_type)
      end
    end
  end
end
