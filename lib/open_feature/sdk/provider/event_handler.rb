# frozen_string_literal: true

require_relative '../provider_event'

module OpenFeature
  module SDK
    module Provider
      # Mixin for providers that emit lifecycle events
      module EventHandler
        def attach(event_dispatcher)
          @event_dispatcher = event_dispatcher
        end

        def detach
          @event_dispatcher = nil
        end

        def emit_event(event_type, details = {})
          return unless @event_dispatcher

          unless ProviderEvent::ALL_EVENTS.include?(event_type)
            raise ArgumentError, "Invalid event type: #{event_type}"
          end

          event_details = details.merge(provider: self)
          
          @event_dispatcher.dispatch_event(self, event_type, event_details)
        end

        def event_dispatcher_attached?
          !@event_dispatcher.nil?
        end
      end
    end
  end
end
