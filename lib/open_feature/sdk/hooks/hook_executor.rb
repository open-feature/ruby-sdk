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
      #
      # The hook context is frozen before after, error and finally hooks run, so only before hooks
      # can change the evaluation context (spec 4.1.4.1). Not earlier: some providers write to it.
      class HookExecutor
        def initialize(logger: nil)
          @logger = logger
        end

        # Runs error hooks and finally hooks for a short-circuit evaluation.
        # Before hooks and after hooks are NOT run.
        #
        # @param ordered_hooks [Array] hooks in before-order
        # @param hook_context [HookContext] the hook context
        # @param hints [Hints] hook hints
        # @param evaluation_details [EvaluationDetails] the short-circuit result
        def run_short_circuit(ordered_hooks:, hook_context:, hints:, evaluation_details:)
          error = EvaluationError.new(evaluation_details.error_message, error_code: evaluation_details.error_code)
          run_error_hooks(ordered_hooks, hook_context, error, hints)
        ensure
          run_finally_hooks(ordered_hooks, hook_context, evaluation_details, hints)
        end

        # Executes the full hook lifecycle around the flag evaluation block.
        #
        # @param ordered_hooks [Array] hooks in before-order (API, Client, Invocation, Provider)
        # @param hook_context [HookContext] the hook context
        # @param hints [Hints] hook hints
        # @param default_value [Object] returned if evaluation raises; the caller's own object, not the hooks' frozen copy
        # @param evaluate_block [Proc] the flag evaluation to wrap
        # @return [EvaluationDetails] the evaluation result
        def execute(ordered_hooks:, hook_context:, hints:, default_value:, &evaluate_block)
          evaluation_details = nil

          begin
            run_before_hooks(ordered_hooks, hook_context, hints)
            evaluation_details = evaluate_block.call(hook_context)

            # Spec 4.3.7: If evaluation resulted in an error (e.g. FLAG_NOT_FOUND,
            # TYPE_MISMATCH), run error hooks instead of after hooks.
            if evaluation_details.error_code
              error = EvaluationError.new(evaluation_details.error_message, error_code: evaluation_details.error_code)
              run_error_hooks(ordered_hooks, hook_context, error, hints)
            else
              run_after_hooks(ordered_hooks, hook_context, evaluation_details, hints)
            end
          rescue StandardError, NotImplementedError => e
            run_error_hooks(ordered_hooks, hook_context, e, hints)

            evaluation_details = EvaluationDetails.new(
              flag_key: hook_context.flag_key,
              resolution_details: Provider::ResolutionDetails.new(
                value: default_value,
                error_code: EvaluationError.code_for(e),
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
          hook_context.freeze
          hooks.reverse_each do |hook|
            next unless hook.respond_to?(:after)
            hook.after(hook_context: hook_context, evaluation_details: evaluation_details, hints: hints)
          end
        end

        # Spec 4.4.4: Error hooks run in reverse order.
        # If an error hook itself errors, log and continue remaining error hooks.
        def run_error_hooks(hooks, hook_context, exception, hints)
          hook_context.freeze
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
          hook_context.freeze
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
