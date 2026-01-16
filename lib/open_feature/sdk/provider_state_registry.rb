# frozen_string_literal: true

require_relative "provider_state"
require_relative "provider_event"
require_relative "provider/error_code"

module OpenFeature
  module SDK
    # Tracks provider states
    class ProviderStateRegistry
      def initialize
        @states = {}
        @mutex = Mutex.new
      end

      def set_initial_state(provider, state = ProviderState::NOT_READY)
        return unless provider

        @mutex.synchronize do
          @states[provider.object_id] = state
        end
      end

      def update_state_from_event(provider, event_type, event_details = nil)
        return ProviderState::NOT_READY unless provider

        new_state = state_from_event(event_type, event_details)

        # Only update state if the event should cause a state change
        if new_state
          @mutex.synchronize do
            @states[provider.object_id] = new_state
          end
          new_state
        else
          # Return current state without changing it
          get_state(provider)
        end
      end

      def get_state(provider)
        return ProviderState::NOT_READY unless provider

        @mutex.synchronize do
          @states[provider.object_id] || ProviderState::NOT_READY
        end
      end

      def remove_provider(provider)
        return unless provider

        @mutex.synchronize do
          @states.delete(provider.object_id)
        end
      end

      def ready?(provider)
        get_state(provider) == ProviderState::READY
      end

      def error?(provider)
        state = get_state(provider)
        [ProviderState::ERROR, ProviderState::FATAL].include?(state)
      end

      def clear
        @mutex.synchronize do
          @states.clear
        end
      end

      private

      def state_from_event(event_type, event_details = nil)
        case event_type
        when ProviderEvent::PROVIDER_READY
          ProviderState::READY
        when ProviderEvent::PROVIDER_STALE
          ProviderState::STALE
        when ProviderEvent::PROVIDER_ERROR
          state_from_error_event(event_details)
        when ProviderEvent::PROVIDER_CONFIGURATION_CHANGED
          nil # No state change per OpenFeature spec Requirement 5.3.5
        else
          nil # No state change for unknown events - conservative default
        end
      end

      def state_from_error_event(event_details)
        error_code = event_details&.dig(:error_code)
        if error_code == Provider::ErrorCode::PROVIDER_FATAL
          ProviderState::FATAL
        else
          ProviderState::ERROR
        end
      end
    end
  end
end
