# frozen_string_literal: true

require_relative '../provider_event'

module OpenFeature
  module SDK
    module Provider
      # EventHandler allows providers to emit lifecycle events.
      # FeatureProviders can opt in for this behavior by including this module.
      #
      # Adapted for Ruby's callback pattern.
      #
      # Example:
      #   class MyProvider
      #     include OpenFeature::SDK::Provider::EventHandler
      #
      #     def init(evaluation_context)
      #       Thread.new do
      #         connect_to_service
      #         emit_event(ProviderEvent::PROVIDER_READY)
      #       end
      #     end
      #   end
      module EventHandler
        # Attach this provider to an event dispatcher.
        # Called by the SDK when the provider is registered.
        #
        # @param event_dispatcher [Object] the dispatcher that will handle events
        def attach(event_dispatcher)
          @event_dispatcher = event_dispatcher
        end

        # Detach this provider from the event dispatcher.
        # Called by the SDK when the provider is being replaced.
        def detach
          @event_dispatcher = nil
        end

        # Emit an event to the attached dispatcher.
        #
        # @param event_type [String] one of the ProviderEvent constants
        # @param details [Hash] optional event details including :message, :error_code
        def emit_event(event_type, details = {})
          return unless @event_dispatcher

          # Ensure we have a valid event type
          unless ProviderEvent::ALL_EVENTS.include?(event_type)
            raise ArgumentError, "Invalid event type: #{event_type}"
          end

          # Add provider reference to details
          event_details = details.merge(provider: self)
          
          @event_dispatcher.dispatch_event(self, event_type, event_details)
        end

        # Check if this provider has an attached event dispatcher
        #
        # @return [Boolean] true if events can be emitted
        def event_dispatcher_attached?
          !@event_dispatcher.nil?
        end
      end
    end
  end
end