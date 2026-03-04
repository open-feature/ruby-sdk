# frozen_string_literal: true

module OpenFeature
  module SDK
    module Hooks
      # Orchestrates the full hook lifecycle for flag evaluation.
      #
      # Hook execution order (spec 4.4.2):
      #   Before: API → Client → Invocation → Provider
      #   After/Error/Finally: Provider → Invocation → Client → API (reverse)
      #
      # Error handling (spec 4.4.3-4.4.7):
      #   - Before/after hook error → stop remaining hooks, run error hooks, return default
      #   - Error hook error → log, continue remaining error hooks
      #   - Finally hook error → log, continue remaining finally hooks
      class HookExecutor
        def initialize(logger: nil)
          @logger = logger
        end

        # Executes the full hook lifecycle around the flag evaluation block.
        #
        # @param ordered_hooks [Array] hooks in before-order (API, Client, Invocation, Provider)
        # @param hook_context [HookContext] the hook context
        # @param hints [Hints] hook hints
        # @param evaluate_block [Proc] the flag evaluation to wrap
        # @return [EvaluationDetails] the evaluation result
        def execute(ordered_hooks:, hook_context:, hints:, &evaluate_block)
          evaluation_details = nil

          begin
            run_before_hooks(ordered_hooks, hook_context, hints)
            evaluation_details = evaluate_block.call(hook_context)
            run_after_hooks(ordered_hooks, hook_context, evaluation_details, hints)
          rescue => e
            run_error_hooks(ordered_hooks, hook_context, e, hints)

            evaluation_details = EvaluationDetails.new(
              flag_key: hook_context.flag_key,
              resolution_details: Provider::ResolutionDetails.new(
                value: hook_context.default_value,
                error_code: Provider::ErrorCode::GENERAL,
                reason: Provider::Reason::ERROR,
                error_message: e.message
              )
            )
          ensure
            run_finally_hooks(ordered_hooks, hook_context, evaluation_details, hints)
          end

          evaluation_details
        end

        private

        # Spec 4.4.2: Before hooks run in order: API → Client → Invocation → Provider
        # Spec 4.3.4/4.3.5: If a before hook returns an EvaluationContext, it is merged
        # into the existing context for subsequent hooks and evaluation.
        def run_before_hooks(hooks, hook_context, hints)
          hooks.each do |hook|
            next unless hook.respond_to?(:before)
            result = hook.before(hook_context: hook_context, hints: hints)
            if result.is_a?(EvaluationContext)
              existing = hook_context.evaluation_context
              hook_context.evaluation_context = existing ? existing.merge(result) : result
            end
          end
        end

        # Spec 4.4.2: After hooks run in reverse order: Provider → Invocation → Client → API
        def run_after_hooks(hooks, hook_context, evaluation_details, hints)
          hooks.reverse_each do |hook|
            next unless hook.respond_to?(:after)
            hook.after(hook_context: hook_context, evaluation_details: evaluation_details, hints: hints)
          end
        end

        # Spec 4.4.4: Error hooks run in reverse order.
        # If an error hook itself errors, log and continue remaining error hooks.
        def run_error_hooks(hooks, hook_context, exception, hints)
          hooks.reverse_each do |hook|
            next unless hook.respond_to?(:error)
            hook.error(hook_context: hook_context, exception: exception, hints: hints)
          rescue => e
            @logger&.error("Error hook #{hook.class.name} failed: #{e.message}")
          end
        end

        # Spec 4.4.3: Finally hooks run in reverse order unconditionally.
        # If a finally hook errors, log and continue remaining finally hooks.
        def run_finally_hooks(hooks, hook_context, evaluation_details, hints)
          hooks.reverse_each do |hook|
            next unless hook.respond_to?(:finally)
            hook.finally(hook_context: hook_context, evaluation_details: evaluation_details, hints: hints)
          rescue => e
            @logger&.error("Finally hook #{hook.class.name} failed: #{e.message}")
          end
        end
      end
    end
  end
end
