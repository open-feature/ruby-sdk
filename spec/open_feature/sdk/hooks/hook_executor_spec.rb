# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Hooks::HookExecutor do
  subject(:executor) { described_class.new(logger: logger) }

  let(:logger) { instance_double("Logger", error: nil, warn: nil) }

  let(:evaluation_context) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-1") }
  let(:hints) { OpenFeature::SDK::Hooks::Hints.new }
  let(:hook_context) do
    OpenFeature::SDK::Hooks::HookContext.new(
      flag_key: "test-flag",
      flag_value_type: :boolean,
      default_value: false,
      evaluation_context: evaluation_context
    )
  end

  let(:successful_details) do
    OpenFeature::SDK::EvaluationDetails.new(
      flag_key: "test-flag",
      resolution_details: OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: true,
        reason: OpenFeature::SDK::Provider::Reason::STATIC
      )
    )
  end

  describe "#execute" do
    context "successful evaluation" do
      it "calls before, evaluate, after, finally in order" do
        call_log = []
        hook = recording_hook("h1", call_log)

        executor.execute(ordered_hooks: [hook], hook_context: hook_context, hints: hints) do |_hctx|
          call_log << "evaluate"
          successful_details
        end

        expect(call_log).to eq(["h1:before", "evaluate", "h1:after", "h1:finally"])
      end

      it "returns the evaluation details from the block" do
        result = executor.execute(ordered_hooks: [], hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        expect(result.value).to eq(true)
        expect(result.flag_key).to eq("test-flag")
      end
    end

    context "hook execution order" do
      it "runs before hooks in insertion order (API → Client → Invocation → Provider)" do
        call_log = []
        hooks = [
          recording_hook("api", call_log),
          recording_hook("client", call_log),
          recording_hook("invocation", call_log),
          recording_hook("provider", call_log)
        ]

        executor.execute(ordered_hooks: hooks, hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        before_calls = call_log.select { |c| c.end_with?(":before") }
        expect(before_calls).to eq(["api:before", "client:before", "invocation:before", "provider:before"])
      end

      it "runs after hooks in reverse order (Provider → Invocation → Client → API)" do
        call_log = []
        hooks = [
          recording_hook("api", call_log),
          recording_hook("client", call_log),
          recording_hook("invocation", call_log),
          recording_hook("provider", call_log)
        ]

        executor.execute(ordered_hooks: hooks, hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        after_calls = call_log.select { |c| c.end_with?(":after") }
        expect(after_calls).to eq(["provider:after", "invocation:after", "client:after", "api:after"])
      end

      it "runs finally hooks in reverse order" do
        call_log = []
        hooks = [
          recording_hook("api", call_log),
          recording_hook("client", call_log),
          recording_hook("provider", call_log)
        ]

        executor.execute(ordered_hooks: hooks, hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        finally_calls = call_log.select { |c| c.end_with?(":finally") }
        expect(finally_calls).to eq(["provider:finally", "client:finally", "api:finally"])
      end
    end

    context "before hook context merging" do
      it "merges EvaluationContext returned by before hook" do
        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(hook_context:, hints:)
            OpenFeature::SDK::EvaluationContext.new(extra_key: "extra_value")
          end
        end.new

        captured_context = nil
        executor.execute(ordered_hooks: [hook], hook_context: hook_context, hints: hints) do |hctx|
          captured_context = hctx.evaluation_context
          successful_details
        end

        expect(captured_context.field("extra_key")).to eq("extra_value")
        expect(captured_context.targeting_key).to eq("user-1")
      end

      it "does not merge non-EvaluationContext returns" do
        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(hook_context:, hints:)
            "not a context"
          end
        end.new

        captured_context = nil
        executor.execute(ordered_hooks: [hook], hook_context: hook_context, hints: hints) do |hctx|
          captured_context = hctx.evaluation_context
          successful_details
        end

        expect(captured_context).to eq(evaluation_context)
      end

      it "passes merged context to subsequent before hooks" do
        contexts_seen = []

        hook1 = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(hook_context:, hints:)
            OpenFeature::SDK::EvaluationContext.new(from_hook1: "yes")
          end
        end.new

        hook2_class = Class.new do
          include OpenFeature::SDK::Hooks::Hook
          define_method(:initialize) { |log| @log = log }

          define_method(:before) do |hook_context:, hints:|
            @log << hook_context.evaluation_context.field("from_hook1")
            nil
          end
        end

        hook2 = hook2_class.new(contexts_seen)

        executor.execute(ordered_hooks: [hook1, hook2], hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        expect(contexts_seen).to eq(["yes"])
      end
    end

    context "error handling" do
      it "runs error hooks when before hook raises" do
        call_log = []
        error_hook = recording_hook("h1", call_log)

        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            raise "before failed"
          end

          define_method(:error) do |hook_context:, exception:, hints:|
            call_log << "failing:error"
          end

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            call_log << "failing:finally"
          end
        end.new

        result = executor.execute(ordered_hooks: [failing_hook, error_hook], hook_context: hook_context, hints: hints) do |_hctx|
          call_log << "evaluate"
          successful_details
        end

        expect(call_log).not_to include("evaluate")
        expect(call_log).to include("failing:error")
        expect(result.value).to eq(false) # default value
        expect(result.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)
      end

      it "runs error hooks when after hook raises" do
        call_log = []

        failing_after_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:after) do |hook_context:, evaluation_details:, hints:|
            raise "after failed"
          end

          define_method(:error) do |hook_context:, exception:, hints:|
            call_log << "error_ran"
          end

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            call_log << "finally_ran"
          end
        end.new

        result = executor.execute(ordered_hooks: [failing_after_hook], hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        expect(call_log).to include("error_ran")
        expect(call_log).to include("finally_ran")
        expect(result.value).to eq(false) # default value
      end

      it "runs error hooks when evaluation block raises" do
        call_log = []
        hook = recording_hook("h1", call_log)

        result = executor.execute(ordered_hooks: [hook], hook_context: hook_context, hints: hints) do |_hctx|
          raise "evaluation failed"
        end

        expect(call_log).to include("h1:error")
        expect(call_log).to include("h1:finally")
        expect(result.value).to eq(false) # default value
        expect(result.error_message).to eq("evaluation failed")
      end

      it "continues remaining error hooks when one error hook fails" do
        call_log = []

        failing_error_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            raise "error hook failed"
          end
        end.new

        good_error_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            call_log << "good_error_ran"
          end
        end.new

        # Hooks are reversed for error stage, so good_error_hook (first in ordered)
        # runs last in error stage. failing_error_hook (second) runs first in error stage.
        executor.execute(ordered_hooks: [good_error_hook, failing_error_hook], hook_context: hook_context, hints: hints) do |_hctx|
          raise "eval failed"
        end

        expect(call_log).to include("good_error_ran")
        expect(logger).to have_received(:error).with(/error hook failed/)
      end

      it "continues remaining finally hooks when one finally hook fails" do
        call_log = []

        failing_finally_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            raise "finally hook failed"
          end
        end.new

        good_finally_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            call_log << "good_finally_ran"
          end
        end.new

        # Hooks are reversed for finally stage
        executor.execute(ordered_hooks: [good_finally_hook, failing_finally_hook], hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        expect(call_log).to include("good_finally_ran")
        expect(logger).to have_received(:error).with(/finally hook failed/)
      end
    end

    context "hooks that only implement some stages" do
      it "skips hooks that do not respond to a stage" do
        before_only_hook = Class.new do
          def before(hook_context:, hints:)
            nil
          end
        end.new

        result = executor.execute(ordered_hooks: [before_only_hook], hook_context: hook_context, hints: hints) do |_hctx|
          successful_details
        end

        expect(result.value).to eq(true)
      end
    end
  end
end
