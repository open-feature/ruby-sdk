# frozen_string_literal: true

require_relative 'provider_event'
require_relative 'provider_state'

module OpenFeature
  module SDK
    # Maps provider events to provider states
    #
    class EventToStateMapper
      # Event details structure for error events
      class EventDetails
        attr_reader :message, :error_code

        def initialize(message: nil, error_code: nil)
          @message = message
          @error_code = error_code
        end
      end

      # Mapping from event types to states
      STATE_MAPPING = {
        ProviderEvent::PROVIDER_READY => ProviderState::READY,
        ProviderEvent::PROVIDER_CONFIGURATION_CHANGED => ProviderState::READY,
        ProviderEvent::PROVIDER_STALE => ProviderState::STALE,
        ProviderEvent::PROVIDER_ERROR => lambda do |event_details|
          # Check if it's a fatal error
          if event_details&.error_code == 'PROVIDER_FATAL'
            ProviderState::FATAL
          else
            ProviderState::ERROR
          end
        end
      }.freeze

      # Map an event type to a provider state
      #
      # @param event_type [String] the event type
      # @param event_details [EventDetails, Hash, nil] optional event details
      # @return [String] the corresponding provider state
      def self.state_from_event(event_type, event_details = nil)
        mapper = STATE_MAPPING[event_type]
        
        if mapper.respond_to?(:call)
          # Convert Hash to EventDetails if needed
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
          mapper || ProviderState::NOT_READY  # default fallback
        end
      end

      # Map an error to a provider state (for direct error handling)
      #
      # @param error [Exception] the error that occurred
      # @return [String] the corresponding provider state
      def self.state_from_error(error)
        # Check if it's a fatal error based on error class or message
        if fatal_error?(error)
          ProviderState::FATAL
        else
          ProviderState::ERROR
        end
      end

      private

      # Determine if an error is fatal
      def self.fatal_error?(error)
        # You can customize this logic based on your error types
        error.is_a?(SystemExit) ||
          error.message&.include?('PROVIDER_FATAL') ||
          error.message&.include?('fatal')
      end
    end
  end
end
