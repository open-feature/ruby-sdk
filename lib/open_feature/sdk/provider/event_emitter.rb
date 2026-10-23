# frozen_string_literal: true

require_relative "../provider_event"

module OpenFeature
  module SDK
    module Provider
      # Mixin for providers that emit lifecycle events
      module EventEmitter
        def emit_event(event_type, details = {})
          config = @openfeature_configuration
          return unless config

          unless ::OpenFeature::SDK::ProviderEvent::ALL_EVENTS.include?(event_type)
            raise ArgumentError, "Invalid event type: #{event_type}"
          end

          config.send(:dispatch_provider_event, self, event_type, details)
        end

        def configuration_attached?
          !@openfeature_configuration.nil?
        end

        private

        def attach(configuration)
          # Spec 1.8.4: only providers using this mixin know which API they're registered with
          if @openfeature_configuration && !@openfeature_configuration.equal?(configuration)
            raise ArgumentError, "Provider is already registered with another OpenFeature API instance"
          end

          @openfeature_configuration = configuration
        end

        def detach
          @openfeature_configuration = nil
        end
      end
    end
  end
end
