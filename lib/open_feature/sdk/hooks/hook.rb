# frozen_string_literal: true

module OpenFeature
  module SDK
    module Hooks
      # Module that hooks include. Provides default no-op implementations
      # for all four lifecycle stages. A hook overrides the stages it cares about.
      #
      # Spec 4.3.1: Hooks MUST specify at least one stage.
      module Hook
        # Called before flag evaluation. May return an EvaluationContext
        # that gets merged into the existing context (spec 4.3.2.1, 4.3.4, 4.3.5).
        def before(hook_context:, hints:)
          nil
        end

        # Called after successful flag evaluation (spec 4.3.3).
        def after(hook_context:, evaluation_details:, hints:)
          nil
        end

        # Called when an error occurs during flag evaluation (spec 4.3.6).
        def error(hook_context:, exception:, hints:)
          nil
        end

        # Called unconditionally after flag evaluation (spec 4.3.7).
        def finally(hook_context:, evaluation_details:, hints:)
          nil
        end
      end
    end
  end
end
