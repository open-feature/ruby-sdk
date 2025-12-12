# frozen_string_literal: true

require_relative 'provider_event'
require_relative 'provider_state'
require_relative 'provider/error_code'

module OpenFeature
  module SDK
    # Maps provider events to provider states
    class EventToStateMapper
      STATE_MAPPING = {
        ProviderEvent::PROVIDER_READY => ProviderState::READY,
        ProviderEvent::PROVIDER_CONFIGURATION_CHANGED => ProviderState::READY,
        ProviderEvent::PROVIDER_STALE => ProviderState::STALE,
        ProviderEvent::PROVIDER_ERROR => lambda { |event_details| state_from_error_event(event_details) }
      }.freeze

      def self.state_from_event(event_type, event_details = nil)
        mapper = STATE_MAPPING[event_type]
        
        if mapper.respond_to?(:call)
          mapper.call(event_details)
        else
          mapper || ProviderState::NOT_READY
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
