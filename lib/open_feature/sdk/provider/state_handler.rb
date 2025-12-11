# frozen_string_literal: true

module OpenFeature
  module SDK
    module Provider
      # Mixin for providers that need initialization and shutdown
      module StateHandler
        def init(evaluation_context)
        end

        def shutdown
        end
      end
    end
  end
end
