# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Hooks Specification" do
  before(:each) do
    OpenFeature::SDK::API.instance.send(:configuration).send(:reset)
  end

  let(:captured) { {} }
  let(:capture_hook) do
    seen = captured
    Class.new do
      include OpenFeature::SDK::Hooks::Hook

      define_method(:before) do |hook_context:, hints:|
        seen[:hook_context] = hook_context
        seen[:hints] = hints
        nil
      end
    end.new
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

      specify "default value MUST be immutable, without freezing the caller's objects" do
        flag_key = +"missing-flag"
        default = {"nested" => {"list" => []}}

        OpenFeature::SDK.build_client.fetch_object_value(flag_key:, default_value: default, hooks: [capture_hook])

        expect(captured[:hook_context].default_value).to eq(default)
        expect(captured[:hook_context].default_value["nested"]["list"]).to be_frozen
        expect(default["nested"]).not_to be_frozen
        expect(default).not_to be_frozen
        expect(flag_key).not_to be_frozen
      end

      specify "the caller gets their own default back when the provider raises" do
        allow(provider).to receive(:fetch_object_value).and_raise("boom")
        default = {"rules" => []}

        details = OpenFeature::SDK.build_client.fetch_object_details(flag_key: "flag-1", default_value: default, hooks: [capture_hook])

        expect(details.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        expect(details.value).to equal(default)
        expect(default).not_to be_frozen
      end
    end

    context "Requirement 4.1.5" do
      specify "Hook context MUST provide a mechanism for hook instances to store and retrieve per-hook data" do
        data_across_stages = {}

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            hook_context.hook_data_for(self)["my_key"] = "set_in_before"
            nil
          end

          define_method(:after) do |hook_context:, evaluation_details:, hints:|
            data_across_stages[:after_value] = hook_context.hook_data_for(self)["my_key"]
          end

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            data_across_stages[:finally_value] = hook_context.hook_data_for(self)["my_key"]
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(data_across_stages[:after_value]).to eq("set_in_before")
        expect(data_across_stages[:finally_value]).to eq("set_in_before")
      end

      specify "Hook data MUST be isolated between different hook instances" do
        hook_a_data = {}
        hook_b_data = {}

        hook_a = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            hook_context.hook_data_for(self)["owner"] = "hook_a"
            nil
          end

          define_method(:after) do |hook_context:, evaluation_details:, hints:|
            hook_a_data[:owner] = hook_context.hook_data_for(self)["owner"]
          end
        end.new

        hook_b = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, hints:|
            hook_context.hook_data_for(self)["owner"] = "hook_b"
            nil
          end

          define_method(:after) do |hook_context:, evaluation_details:, hints:|
            hook_b_data[:owner] = hook_context.hook_data_for(self)["owner"]
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook_a, hook_b])

        expect(hook_a_data[:owner]).to eq("hook_a")
        expect(hook_b_data[:owner]).to eq("hook_b")
      end
    end

    context "Conditional Requirement 4.1.4.1" do
      let(:user) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-1") }
      let(:stages_seen) { {} }

      def context_probe(*stages)
        seen = stages_seen
        Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:attempt) do |&change|
            change.call
            :mutable
          rescue FrozenError
            :frozen
          end

          stages.each do |stage|
            define_method(stage) do |hook_context:, **|
              ctx = hook_context.evaluation_context
              seen[stage] = [attempt { ctx.fields["probe"] = stage }, attempt { hook_context.evaluation_context = ctx }]
            end
          end
        end.new
      end

      specify "the evaluation context can be changed or replaced in before hooks, and not in after and finally hooks" do
        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, evaluation_context: user,
          hooks: [context_probe(:before, :after, :finally)])

        expect(stages_seen).to eq(before: [:mutable, :mutable], after: [:frozen, :frozen], finally: [:frozen, :frozen])
        expect(user).not_to be_frozen
        expect(user.fields).not_to be_frozen
      end

      specify "after hooks can't edit the caller's strings in the evaluation context in place" do
        targeting_key = +"user-1"
        edited = nil
        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:after) do |hook_context:, **|
            hook_context.evaluation_context.targeting_key.replace("other-user")
            edited = true
          rescue FrozenError
            edited = false
          end
        end.new

        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false,
          evaluation_context: OpenFeature::SDK::EvaluationContext.new(targeting_key:), hooks: [hook])

        expect(edited).to be(false)
        expect(targeting_key).to eq("user-1")
        expect(targeting_key).not_to be_frozen
      end

      specify "after hooks can't change nested values in the caller's evaluation context" do
        regions = ["us"]
        outcome = nil
        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:after) do |hook_context:, **|
            hook_context.evaluation_context.field("regions") << "eu"
            outcome = :changed
          rescue FrozenError
            outcome = :frozen
          end
        end.new
        OpenFeature::SDK.configure { |config| config.evaluation_context = OpenFeature::SDK::EvaluationContext.new(regions:) }

        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(outcome).to eq(:frozen)
        expect(regions).to eq(["us"])
        expect(regions).not_to be_frozen
      end

      specify "objects in the evaluation context reach after hooks as they are, so reading them can't fail" do
        user_class = Class.new do
          def name = @name ||= +"Ada"
        end
        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:after) { |hook_context:, **| hook_context.evaluation_context.field("user").name }
        end.new

        details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag-1", default_value: false,
          evaluation_context: OpenFeature::SDK::EvaluationContext.new(user: user_class.new), hooks: [hook])

        expect(details.value).to be(true)
        expect(details.error_code).to be_nil
      end

      specify "the evaluation context is frozen in error and finally hooks when a before hook raises" do
        failing_before = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def before(**) = raise("boom")
        end.new

        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, evaluation_context: user,
          hooks: [context_probe(:error, :finally), failing_before])

        expect(stages_seen).to eq(error: [:frozen, :frozen], finally: [:frozen, :frozen])
      end

      specify "a provider can still write to the evaluation context while hooks are registered" do
        writing_provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
          def fetch_boolean_value(evaluation_context:, **)
            evaluation_context.fields["written_by_provider"] = true
            super
          end
        end.new({"flag-1" => true})
        OpenFeature::SDK.set_provider_and_wait(writing_provider)

        details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag-1", default_value: false,
          evaluation_context: user, hooks: [context_probe(:finally)])

        expect(details.value).to be(true)
        expect(details.error_code).to be_nil
      end

      specify "a context a before hook returns isn't frozen afterwards" do
        returned = OpenFeature::SDK::EvaluationContext.new(targeting_key: "from-hook")
        seen_targeting_key = nil
        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) { |**| returned }
          define_method(:after) { |hook_context:, **| seen_targeting_key = hook_context.evaluation_context.targeting_key }
        end.new

        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(seen_targeting_key).to eq("from-hook")
        expect(returned).not_to be_frozen
      end
    end
  end

  context "4.2 - Hook Hints" do
    let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new({"flag-1" => true}) }

    before { OpenFeature::SDK.set_provider_and_wait(provider) }

    context "Requirement 4.2.1" do
      specify "hook hints MUST support boolean, number and datetime values" do
        now = Time.now
        hints = {"bool" => true, "int" => 1, "float" => 1.5, "time" => now}

        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [capture_hook], hook_hints: hints)

        expect(captured[:hints].to_h).to eq(hints)
      end
    end

    context "Conditional Requirement 4.2.2.1" do
      specify "hook hints MUST be immutable, including nested values, without freezing the caller's hash" do
        hint_hash = {"nested" => {"list" => []}}

        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [capture_hook], hook_hints: hint_hash)

        expect(captured[:hints]["nested"]["list"]).to be_frozen
        expect(hint_hash["nested"]["list"]).not_to be_frozen
      end

      specify "hints that can't be deep-copied still evaluate the flag" do
        details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag-1", default_value: false,
          hooks: [capture_hook], hook_hints: {"lookup" => Hash.new { |h, k| h[k] = k }})

        expect(details.value).to be(true)
        expect(captured[:hints]).to be_frozen
      end
    end

    context "Conditional Requirement 4.2.2.2" do
      specify "the client metadata in the hook context MUST be immutable" do
        OpenFeature::SDK.build_client(domain: "my-domain").fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [capture_hook])

        expect(captured[:hook_context].client_metadata).to be_frozen
        expect(captured[:hook_context].client_metadata.domain).to be_frozen
      end
    end

    context "Conditional Requirement 4.2.2.3" do
      let(:provider) do
        Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
          def metadata = @unfrozen_metadata ||= OpenFeature::SDK::Provider::ProviderMetadata.new(name: +"custom")
        end.new({"flag-1" => true})
      end

      specify "the provider metadata in the hook context MUST be immutable, and the provider's own is left alone" do
        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [capture_hook])

        hook_metadata = captured[:hook_context].provider_metadata
        expect { hook_metadata.name = "renamed" }.to raise_error(FrozenError)
        expect { hook_metadata.name << "!" }.to raise_error(FrozenError)
        expect(provider.metadata.name).to eq("custom")
        expect(provider.metadata).not_to be_frozen
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
      let(:hook_data_seen) { [] }
      let(:hook_data_probe) do
        seen = hook_data_seen
        Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:before) do |hook_context:, **|
            data = hook_context.hook_data_for(self)
            seen << [:before, data.dup]
            data["set_in"] = "before"
            nil
          end

          define_method(:error) { |hook_context:, **| seen << [:error, hook_context.hook_data_for(self).dup] }
        end.new
      end

      specify "hook data set in the before stage reaches the error stage" do
        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "missing", default_value: false, hooks: [hook_data_probe])

        expect(hook_data_seen).to eq([[:before, {}], [:error, {"set_in" => "before"}]])
      end

      specify "each evaluation starts with fresh hook data" do
        client = OpenFeature::SDK.build_client
        2.times { client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook_data_probe]) }

        expect(hook_data_seen).to eq([[:before, {}], [:before, {}]])
      end
    end

    context "Conditional Requirement 4.3.2.1" do
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

    context "Requirement 4.3.5" do
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

    context "Requirement 4.3.7" do
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

    context "Requirement 4.3.8" do
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

      specify "On success, finally hook receives evaluation details with the resolved value" do
        captured_details = nil

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            captured_details = evaluation_details
          end
        end.new

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(captured_details).not_to be_nil
        expect(captured_details.value).to eq(true)
        expect(captured_details.flag_key).to eq("flag-1")
      end

      specify "On error, finally hook receives evaluation details with default value and error info" do
        captured_details = nil

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            captured_details = evaluation_details
          end
        end.new

        allow(provider).to receive(:fetch_boolean_value).and_raise("provider error")

        client = OpenFeature::SDK.build_client
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hook])

        expect(captured_details).not_to be_nil
        expect(captured_details.value).to eq(false)
        expect(captured_details.flag_key).to eq("flag-1")
        expect(captured_details.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        expect(captured_details.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
        expect(captured_details.error_message).to eq("provider error")
      end
    end
  end

  context "4.4 - Hook Registration & Ordering" do
    let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new({"flag-1" => true}) }

    before do
      OpenFeature::SDK.set_provider_and_wait(provider)
    end

    context "Requirement 4.4.1" do
      specify "API, Client, Provider, and invocation hooks MUST be registered" do
        call_log = []
        provider_hook = recording_hook("provider", call_log)
        provider_with_hooks = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
          define_method(:hooks) { [provider_hook] }
        end.new({"flag-1" => true})
        OpenFeature::SDK.set_provider_and_wait(provider_with_hooks)

        api_hook = recording_hook("api", call_log)
        client_hook = recording_hook("client", call_log)
        invocation_hook = recording_hook("invocation", call_log)

        OpenFeature::SDK.hooks << api_hook
        client = OpenFeature::SDK.build_client
        client.hooks << client_hook
        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [invocation_hook])

        expect(call_log).to include("api:before", "client:before", "invocation:before", "provider:before")
      end
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

      specify "After and Finally hooks run in reverse order: Provider → Invocation → Client → API" do
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

      specify "Error hooks run in reverse order: Provider → Invocation → Client → API" do
        call_log = []
        OpenFeature::SDK.hooks << recording_hook("api", call_log)
        allow(provider).to receive(:hooks).and_return([recording_hook("provider", call_log)])

        client = OpenFeature::SDK.build_client
        client.hooks << recording_hook("client", call_log)
        client.fetch_boolean_value(flag_key: "missing", default_value: false, hooks: [recording_hook("invocation", call_log)])

        error_calls = call_log.select { |c| c.end_with?(":error") }
        expect(error_calls).to eq(["provider:error", "invocation:error", "client:error", "api:error"])
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

      specify "a finally hook raising NotImplementedError doesn't stop the others or change the result" do
        call_log = []
        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) { |**| raise NotImplementedError, "finally" }
        end.new
        surviving_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:finally) { |**| call_log << "surviving_finally" }
        end.new

        details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag-1", default_value: false, hooks: [surviving_hook, failing_hook])

        expect(call_log).to eq(["surviving_finally"])
        expect(details.value).to be(true)
        expect(details.error_code).to be_nil
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

      specify "an error hook raising NotImplementedError doesn't stop the others, and runs once" do
        call_log = []
        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |**|
            call_log << "failing_error"
            raise NotImplementedError, "error hook"
          end
        end.new
        surviving_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) { |**| call_log << "surviving_error" }
        end.new

        details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "missing-flag", default_value: false, hooks: [surviving_hook, failing_hook])

        expect(call_log).to eq(["failing_error", "surviving_error"])
        expect(details.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
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

      specify "If an after hook abnormally terminates, remaining after hooks MUST NOT be invoked" do
        call_log = []
        first_added = recording_hook("first_added", call_log)
        failing_hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          def after(**) = raise("after failed")
        end.new

        # After hooks run in reverse, so failing_hook runs first
        OpenFeature::SDK.build_client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [first_added, failing_hook])

        expect(call_log).not_to include("first_added:after")
        expect(call_log).to include("first_added:error")
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

  context "4.5 - Flag evaluation options" do
    before { OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new({"flag-1" => true})) }

    context "Requirement 4.5.2" do
      specify "hook hints MUST be passed to every stage of each hook" do
        seen = []
        hint_probe = ->(name) {
          Class.new do
            include OpenFeature::SDK::Hooks::Hook

            %i[before after error finally].each do |stage|
              define_method(stage) do |hints:, **|
                seen << [name, stage, hints["h"]]
                nil
              end
            end
          end.new
        }
        client = OpenFeature::SDK.build_client

        client.fetch_boolean_value(flag_key: "flag-1", default_value: false, hooks: [hint_probe.call(:a), hint_probe.call(:b)], hook_hints: {"h" => "v"})
        client.fetch_boolean_value(flag_key: "missing", default_value: false, hooks: [hint_probe.call(:c)], hook_hints: {"h" => "v"})

        expect(seen).to contain_exactly(
          [:a, :before, "v"], [:a, :after, "v"], [:a, :finally, "v"],
          [:b, :before, "v"], [:b, :after, "v"], [:b, :finally, "v"],
          [:c, :before, "v"], [:c, :error, "v"], [:c, :finally, "v"]
        )
      end
    end
  end
end
