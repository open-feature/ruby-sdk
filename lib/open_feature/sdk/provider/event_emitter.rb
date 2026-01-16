# frozen_string_literal: true

require_relative "../provider_event"

module OpenFeature
  module SDK
    module Provider
      # Mixin for providers that emit lifecycle events
      module EventEmitter
        def emit_event(event_type, details = {})
          config = @configuration
          return unless config

          unless ::OpenFeature::SDK::ProviderEvent::ALL_EVENTS.include?(event_type)
            raise ArgumentError, "Invalid event type: #{event_type}"
          end

          config.send(:dispatch_provider_event, self, event_type, details)
        end

        def configuration_attached?
          !@configuration.nil?
        end

        private

        def attach(configuration)
          @configuration = configuration
        end

        def detach
          @configuration = nil
        end
      end
    end
  end
end
