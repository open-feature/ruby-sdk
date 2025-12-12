# frozen_string_literal: true

require_relative 'provider_event'
require_relative 'provider_state'
require_relative 'provider/error_code'

module OpenFeature
  module SDK
    # Maps provider events to provider states
    class EventToStateMapper
      def self.state_from_event(event_type, event_details = nil)
        case event_type
        when ProviderEvent::PROVIDER_READY, ProviderEvent::PROVIDER_CONFIGURATION_CHANGED
          ProviderState::READY
        when ProviderEvent::PROVIDER_STALE
          ProviderState::STALE
        when ProviderEvent::PROVIDER_ERROR
          state_from_error_event(event_details)
        else
          ProviderState::NOT_READY
        end
      end

      private

      def self.state_from_error_event(event_details)
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
