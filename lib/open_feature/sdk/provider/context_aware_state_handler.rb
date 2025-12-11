# frozen_string_literal: true

require 'timeout'
require_relative 'state_handler'

module OpenFeature
  module SDK
    module Provider
      # StateHandler with timeout support for initialization and shutdown
      module ContextAwareStateHandler
        include StateHandler

        def init_with_timeout(evaluation_context, timeout: 30)
          Timeout.timeout(timeout) do
            init(evaluation_context)
          end
        end

        def shutdown_with_timeout(timeout: 10)
          Timeout.timeout(timeout) do
            shutdown
          end
        end
      end
    end
  end
end
