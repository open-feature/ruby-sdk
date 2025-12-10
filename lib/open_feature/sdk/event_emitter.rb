# frozen_string_literal: true

require_relative 'provider_event'

module OpenFeature
  module SDK
    # Event Emitter for Provider Lifecycle Events
    #
    # Implements a pub-sub model for provider events
    class EventEmitter
      def initialize
        @handlers = {}
        @mutex = Mutex.new
        ProviderEvent::ALL_EVENTS.each { |event| @handlers[event] = [] }
      end

      # Add a handler for a specific event type
      #
      # @param event_type [String] the event type to listen for
      # @param handler [Proc] the handler to call when event is triggered
      def add_handler(event_type, handler)
        raise ArgumentError, "Invalid event type: #{event_type}" unless valid_event?(event_type)
        raise ArgumentError, "Handler must respond to call" unless handler.respond_to?(:call)

        @mutex.synchronize do
          @handlers[event_type] << handler
        end
      end

      # Remove a specific handler for an event type
      #
      # @param event_type [String] the event type
      # @param handler [Proc] the specific handler to remove
      def remove_handler(event_type, handler)
        return unless valid_event?(event_type)

        @mutex.synchronize do
          @handlers[event_type].delete(handler)
        end
      end

      # Remove all handlers for an event type
      #
      # @param event_type [String] the event type
      def remove_all_handlers(event_type)
        return unless valid_event?(event_type)

        @mutex.synchronize do
          @handlers[event_type].clear
        end
      end

      # Trigger an event with event details
      #
      # @param event_type [String] the event type to trigger
      # @param event_details [Hash] details about the event
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
          rescue => e
            # Log error but don't let one handler failure stop others
            warn "Event handler failed for #{event_type}: #{e.message}"
          end
        end
      end

      # Get count of handlers for an event type (for testing)
      #
      # @param event_type [String] the event type
      # @return [Integer] number of handlers registered
      def handler_count(event_type)
        return 0 unless valid_event?(event_type)

        @mutex.synchronize do
          @handlers[event_type].size
        end
      end

      # Clear all handlers (for testing/cleanup)
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
