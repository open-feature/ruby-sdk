# frozen_string_literal: true

module OpenFeature
  module SDK
    module Provider
      # StateHandler is the contract for initialization & shutdown.
      # FeatureProviders can opt in for this behavior by including this module
      # and implementing the methods.
      #
      #
      # Example:
      #   class MyProvider
      #     include OpenFeature::SDK::Provider::StateHandler
      #
      #     def init(evaluation_context)
      #       # Initialize provider resources
      #       connect_to_service
      #     end
      #
      #     def shutdown
      #       # Cleanup provider resources
      #       disconnect_from_service
      #     end
      #   end
      module StateHandler
        # Initialize the provider with the given evaluation context.
        # This method is called when the provider is set.
        #
        # @param evaluation_context [EvaluationContext] the context for initialization
        # @raise [StandardError] if initialization fails
        def init(evaluation_context)
          # Default implementation - override in provider
        end

        # Shutdown the provider and cleanup resources.
        # This method is called when the provider is being replaced or shutdown.
        def shutdown
          # Default implementation - override in provider
        end
      end
    end
  end
end