# frozen_string_literal: true

require_relative 'no_op_provider'
require_relative 'state_handler'
require_relative 'event_handler'

module OpenFeature
  module SDK
    module Provider
      # EventAwareNoOpProvider extends NoOpProvider with event support.
      # This demonstrates how providers can implement the new interfaces
      # while maintaining backward compatibility.
      #
      # This provider:
      # - Implements StateHandler for initialization/shutdown
      # - Implements EventHandler for event emission
      # - Emits PROVIDER_READY immediately on init
      # - Returns default values like NoOpProvider
      class EventAwareNoOpProvider < NoOpProvider
        include StateHandler
        include EventHandler

        def init(evaluation_context)
          # NoOp provider initializes instantly
          # In a real provider, this might connect to a service
          emit_event(ProviderEvent::PROVIDER_READY, message: "NoOp provider initialized")
        rescue => e
          emit_event(ProviderEvent::PROVIDER_ERROR, 
                    message: "Failed to initialize: #{e.message}",
                    error_code: 'INITIALIZATION_ERROR')
          raise
        end

        def shutdown
          # NoOp provider has nothing to cleanup
          # In a real provider, this might close connections
        end
      end
    end
  end
end