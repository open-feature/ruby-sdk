# frozen_string_literal: true

require_relative 'provider_event'
require_relative 'provider_state'

module OpenFeature
  module SDK
    # Maps provider events to provider states
    class EventToStateMapper
      class EventDetails
        attr_reader :message, :error_code

        def initialize(message: nil, error_code: nil)
          @message = message
          @error_code = error_code
        end
      end

      STATE_MAPPING = {
        ProviderEvent::PROVIDER_READY => ProviderState::READY,
        ProviderEvent::PROVIDER_CONFIGURATION_CHANGED => ProviderState::READY,
        ProviderEvent::PROVIDER_STALE => ProviderState::STALE,
        ProviderEvent::PROVIDER_ERROR => lambda do |event_details|
          if event_details&.error_code == 'PROVIDER_FATAL'
            ProviderState::FATAL
          else
            ProviderState::ERROR
          end
        end
      }.freeze

      def self.state_from_event(event_type, event_details = nil)
        mapper = STATE_MAPPING[event_type]
        
        if mapper.respond_to?(:call)
          details = case event_details
                   when EventDetails
                     event_details
                   when Hash
                     EventDetails.new(
                       message: event_details[:message] || event_details['message'],
                       error_code: event_details[:error_code] || event_details['error_code']
                     )
                   else
                     nil
                   end
          mapper.call(details)
        else
          mapper || ProviderState::NOT_READY
        end
      end

    end
  end
end
