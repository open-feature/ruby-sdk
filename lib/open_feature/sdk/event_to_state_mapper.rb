# frozen_string_literal: true

require_relative 'provider_event'
require_relative 'provider_state'

module OpenFeature
  module SDK
    # Maps provider events to provider states
    class EventToStateMapper
      STATE_MAPPING = {
        ProviderEvent::PROVIDER_READY => ProviderState::READY,
        ProviderEvent::PROVIDER_CONFIGURATION_CHANGED => ProviderState::READY,
        ProviderEvent::PROVIDER_STALE => ProviderState::STALE,
        ProviderEvent::PROVIDER_ERROR => lambda do |event_details|
          error_code = event_details&.dig(:error_code)
          if error_code == 'PROVIDER_FATAL'
            ProviderState::FATAL
          else
            ProviderState::ERROR
          end
        end
      }.freeze

      def self.state_from_event(event_type, event_details = nil)
        mapper = STATE_MAPPING[event_type]
        
        if mapper.respond_to?(:call)
          mapper.call(event_details)
        else
          mapper || ProviderState::NOT_READY
        end
      end

    end
  end
end
