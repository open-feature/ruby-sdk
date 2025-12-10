# frozen_string_literal: true

require 'timeout'
require_relative 'state_handler'

module OpenFeature
  module SDK
    module Provider
      # ContextAwareStateHandler extends StateHandler with timeout support
      # for providers that need bounded initialization and shutdown times.
      #
      # Use this interface when your provider needs to:
      # - Respect initialization/shutdown timeouts (e.g., network calls, database connections)
      # - Support graceful cancellation during setup and teardown
      #
      # Best practices:
      # - Use reasonable timeout values (typically 5-30 seconds)
      # - Handle Timeout::Error gracefully
      # - Maintain backward compatibility by implementing both init methods
      #
      # Example:
      #   class MyProvider
      #     include OpenFeature::SDK::Provider::ContextAwareStateHandler
      #
      #     def init_with_timeout(evaluation_context, timeout: 30)
      #       Timeout.timeout(timeout) do
      #         connect_to_remote_service
      #       end
      #     rescue Timeout::Error => e
      #       raise ProviderInitializationError, "Connection timeout after #{timeout}s"
      #     end
      #
      #     def shutdown_with_timeout(timeout: 10)
      #       Timeout.timeout(timeout) do
      #         disconnect_from_service
      #       end
      #     rescue Timeout::Error
      #       # Force close if graceful shutdown times out
      #       force_disconnect
      #     end
      #   end
      module ContextAwareStateHandler
        include StateHandler

        # Initialize the provider with timeout support.
        #
        # @param evaluation_context [EvaluationContext] the context for initialization
        # @param timeout [Numeric] maximum seconds to wait for initialization
        # @raise [Timeout::Error] if initialization exceeds timeout
        # @raise [StandardError] if initialization fails
        def init_with_timeout(evaluation_context, timeout: 30)
          # Default implementation delegates to regular init
          # Providers can override to add timeout handling
          Timeout.timeout(timeout) do
            init(evaluation_context)
          end
        end

        # Shutdown the provider with timeout support.
        #
        # @param timeout [Numeric] maximum seconds to wait for shutdown
        # @raise [Timeout::Error] if shutdown exceeds timeout
        def shutdown_with_timeout(timeout: 10)
          # Default implementation delegates to regular shutdown
          # Providers can override to add timeout handling
          Timeout.timeout(timeout) do
            shutdown
          end
        end
      end
    end
  end
end
