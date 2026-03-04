# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Hooks Specification" do
  before(:each) do
    OpenFeature::SDK::API.instance.send(:configuration).send(:reset)
  end

  context "4.1 - Hook Context" do
    let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new({"flag-1" => true}) }

    before do
      OpenFeature::SDK.set_provider_and_wait(provider)
    end

    context "Requirement 4.1.1" do
      specify "Hook context MUST provide: flag key, flag value type, default value, evaluation context" do
        captured_context = nil

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            captured_context = hook_context
            nil
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(captured_context.flag_key).to eq("flag-1")
        expect(captured_context.flag_value_type).to eq(:boolean)
        expect(captured_context.default_value).to eq(false)
        expect(captured_context.evaluation_context).to be_nil.or be_a(OpenFeature::SDK::EvaluationContext)
      end
    end

    context "Requirement 4.1.2" do
      specify "Hook context SHOULD provide: client metadata, provider metadata" do
        captured_context = nil

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            captured_context = hook_context
            nil
          end
        end.new

        client = OpenFeature::SDK.build_client(domain: "test-domain")
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(captured_context.client_metadata).to be_a(OpenFeature::SDK::ClientMetadata)
        expect(captured_context.client_metadata.domain).to eq("test-domain")
        expect(captured_context.provider_metadata).to be_a(OpenFeature::SDK::Provider::ProviderMetadata)
        expect(captured_context.provider_metadata.name).to eq("In-memory Provider")
      end
    end

    context "Requirement 4.1.3" do
      specify "flag key and flag value type MUST be immutable" do
        captured_context = nil

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            captured_context = hook_context
            nil
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(captured_context.flag_key).to be_frozen
        expect(captured_context.flag_value_type).to be_frozen
      end
    end

    context "Requirement 4.1.4" do
      specify "evaluation context MUST be mutable" do
        captured_context = nil

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            captured_context = hook_context
            nil
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(
          flag_key: "flag-1",
          default_value: false,
          evaluation_context: OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-1"),
          hooks: [hook]
        )

        expect { captured_context.evaluation_context = OpenFeature::SDK::EvaluationContext.new }.not_to raise_error
      end
    end
  end

  context "4.3 - Hook Stages" do
    let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new({"flag-1" => true}) }

    before do
      OpenFeature::SDK.set_provider_and_wait(provider)
    end

    context "Requirement 4.3.1" do
      specify "Hooks MUST specify at least one stage" do
        hook_module = OpenFeature::SDK::Hooks::Hook

        expect(hook_module.instance_methods).to include(:before, :after, :error, :finally)
      end
    end

    context "Requirement 4.3.2" do
      specify "The before stage MUST run before flag evaluation" do
        call_log = []

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            call_log << "before"
            nil
          end
        end.new

        original_fetch = provider.method(:fetch_boolean_value)
        allow(provider).to receive(:fetch_boolean_value) do |**args|
          call_log << "evaluate"
          original_fetch.call(**args)
        end

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(call_log).to eq(["before", "evaluate"])
      end
    end

    context "Requirement 4.3.3" do
      specify "The after stage MUST run after flag evaluation succeeds" do
        after_ran = false

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:after) do |hook_context:, evaluation_details:, hints:|
            after_ran = true
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(after_ran).to be true
      end
    end

    context "Requirement 4.3.4" do
      specify "If a before hook returns an evaluation context, it MUST be merged with the existing context" do
        captured_eval_context = nil

        context_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(hook_context:, hints:)
            OpenFeature::SDK::EvaluationContext.new(hook_key: "hook_value")
          end
        end.new

        original_fetch = provider.method(:fetch_boolean_value)
        allow(provider).to receive(:fetch_boolean_value) do |**args|
          captured_eval_context = args[:evaluation_context]
          original_fetch.call(**args)
        end

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(
          flag_key: "flag-1",
          default_value: false,
          evaluation_context: OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-1"),
          hooks: [context_hook]
        )

        expect(captured_eval_context.field("hook_key")).to eq("hook_value")
        expect(captured_eval_context.targeting_key).to eq("user-1")
      end
    end

    context "Requirement 4.3.6" do
      specify "The error stage MUST run when errors are raised" do
        error_ran = false
        captured_exception = nil

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            error_ran = true
            captured_exception = exception
          end
        end.new

        allow(provider).to receive(:fetch_boolean_value).and_raise("provider error")

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(error_ran).to be true
        expect(captured_exception.message).to eq("provider error")
      end
    end

    context "Requirement 4.3.7" do
      specify "The finally stage MUST run unconditionally" do
        finally_count = 0

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            finally_count += 1
          end
        end.new

        client = OpenFeature::SDK.build_client

        # Success case
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])
        expect(finally_count).to eq(1)

        # Error case
        allow(provider).to receive(:fetch_boolean_value).and_raise("error")
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])
        expect(finally_count).to eq(2)
      end
    end
  end

  context "4.4 - Hook Execution" do
    let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new({"flag-1" => true}) }

    before do
      OpenFeature::SDK.set_provider_and_wait(provider)
    end

    context "Requirement 4.4.2" do
      specify "Before hooks run in order: API → Client → Invocation → Provider" do
        call_log = []
        api_hook = recording_hook("api", call_log)
        client_hook = recording_hook("client", call_log)
        invocation_hook = recording_hook("invocation", call_log)
        provider_hook = recording_hook("provider", call_log)

        OpenFeature::SDK.hooks << api_hook
        allow(provider).to receive(:hooks).and_return([provider_hook])

        client = OpenFeature::SDK.build_client
        client.hooks << client_hook
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [invocation_hook])

        before_calls = call_log.select { |c| c.end_with?(":before") }
        expect(before_calls).to eq(["api:before", "client:before", "invocation:before", "provider:before"])
      end

      specify "After, Error, and Finally hooks run in reverse order: Provider → Invocation → Client → API" do
        call_log = []
        api_hook = recording_hook("api", call_log)
        client_hook = recording_hook("client", call_log)
        invocation_hook = recording_hook("invocation", call_log)
        provider_hook = recording_hook("provider", call_log)

        OpenFeature::SDK.hooks << api_hook
        allow(provider).to receive(:hooks).and_return([provider_hook])

        client = OpenFeature::SDK.build_client
        client.hooks << client_hook
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [invocation_hook])

        after_calls = call_log.select { |c| c.end_with?(":after") }
        expect(after_calls).to eq(["provider:after", "invocation:after", "client:after", "api:after"])

        finally_calls = call_log.select { |c| c.end_with?(":finally") }
        expect(finally_calls).to eq(["provider:finally", "invocation:finally", "client:finally", "api:finally"])
      end
    end

    context "Requirement 4.4.3" do
      specify "If a finally hook abnormally terminates, remaining finally hooks MUST still run" do
        call_log = []

        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            raise "finally failed"
          end
        end.new

        surviving_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            call_log << "surviving_finally"
          end
        end.new

        # surviving_hook is first in order, so reversed it comes last → runs after failing_hook
        # failing_hook is second in order, so reversed it comes first
        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [surviving_hook, failing_hook])

        expect(call_log).to include("surviving_finally")
      end
    end

    context "Requirement 4.4.4" do
      specify "If an error hook abnormally terminates, remaining error hooks MUST still run" do
        call_log = []

        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            raise "error hook failed"
          end
        end.new

        surviving_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            call_log << "surviving_error"
          end
        end.new

        allow(provider).to receive(:fetch_boolean_value).and_raise("provider error")

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [surviving_hook, failing_hook])

        expect(call_log).to include("surviving_error")
      end
    end

    context "Requirement 4.4.5" do
      specify "If a before/after hook raises, error hooks MUST be invoked" do
        error_ran = false

        failing_before = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(hook_context:, hints:)
            raise "before failed"
          end
        end.new

        error_catcher = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            error_ran = true
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [error_catcher, failing_before])

        expect(error_ran).to be true
      end
    end

    context "Requirement 4.4.6" do
      specify "If a before hook abnormally terminates, remaining before hooks MUST NOT be invoked" do
        second_before_ran = false

        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(hook_context:, hints:)
            raise "before failed"
          end
        end.new

        second_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            second_before_ran = true
            nil
          end
        end.new

        # failing_hook is first in order, so second_hook.before should not run
        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [failing_hook, second_hook])

        expect(second_before_ran).to be false
      end
    end

    context "Requirement 4.4.7" do
      specify "When a hook abnormally terminates, the default value MUST be returned" do
        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(hook_context:, hints:)
            raise "before failed"
          end
        end.new

        client = OpenFeature::SDK.build_client
        result = client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [failing_hook])

        expect(result).to eq(false)
      end
    end
  end

  context "4.5 - Hook Registration" do
    before(:each) do
      OpenFeature::SDK::API.instance.send(:configuration).send(:reset)
    end

    context "Requirement 4.5.1" do
      specify "API, Client, and invocation hooks MUST be registered" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new({"flag-1" => true})
        OpenFeature::SDK.set_provider_and_wait(provider)

        call_log = []
        api_hook = recording_hook("api", call_log)
        client_hook = recording_hook("client", call_log)
        invocation_hook = recording_hook("invocation", call_log)

        OpenFeature::SDK.hooks << api_hook
        client = OpenFeature::SDK.build_client
        client.hooks << client_hook
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [invocation_hook])

        expect(call_log).to include("api:before", "client:before", "invocation:before")
      end
    end
  end
end
