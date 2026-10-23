# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Provider" do
  context "2.1 - Feature Provider Interface" do
    context "Requirement 2.1.1" do
      specify "The provider interface MUST define a metadata member or accessor, containing a name field or accessor of type string, which identifies the provider implementation." do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        expect(provider.metadata.name).to eq("No-op Provider")
      end
    end
  end

  context "2.4 - Initialization" do
    context "Requirement 2.4.2.1" do
      specify "The provider initialization function, if defined, SHOULD indicate an error if flag evaluation does NOT become possible" do
        # Create a provider that cannot initialize properly
        failing_provider_class = Class.new do
          include OpenFeature::SDK::Provider::EventEmitter

          def metadata
            OpenFeature::SDK::Provider::ProviderMetadata.new(name: "Failing Provider")
          end

          def init(_evaluation_context)
            # Simulate inability to connect to flag service
            raise StandardError, "Cannot connect to flag service"
          end

          def shutdown
            # no-op
          end

          def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
            OpenFeature::SDK::Provider::ResolutionDetails.new(
              value: default_value,
              reason: OpenFeature::SDK::Provider::Reason::ERROR
            )
          end
        end

        provider = failing_provider_class.new

        # Using set_provider_and_wait should raise an error when init fails
        expect do
          OpenFeature::SDK.set_provider_and_wait(provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include("Cannot connect to flag service")
        end
      end

      specify "Requirement 1.7.5: Provider status indicates FATAL if init terminates with PROVIDER_FATAL error code" do
        fatal_error_class = Class.new(StandardError) do
          define_method(:error_code) { OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL }
        end

        fatal_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        allow(fatal_provider).to receive(:init).and_raise(fatal_error_class.new("Fatal init failure"))

        expect do
          OpenFeature::SDK.set_provider_and_wait(fatal_provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL)
        end

        # Provider state should be FATAL, not ERROR
        state = OpenFeature::SDK.configuration.provider_state(fatal_provider)
        expect(state).to eq(OpenFeature::SDK::ProviderState::FATAL)
      end

      specify "Requirement 1.7.4: Provider status indicates ERROR for non-fatal init errors" do
        generic_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        allow(generic_provider).to receive(:init).and_raise(StandardError.new("Generic init failure"))

        expect do
          OpenFeature::SDK.set_provider_and_wait(generic_provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        end

        state = OpenFeature::SDK.configuration.provider_state(generic_provider)
        expect(state).to eq(OpenFeature::SDK::ProviderState::ERROR)
      end

      specify "An init error whose error_code reader raises still becomes a GENERAL ProviderInitializationError" do
        error_class = Class.new(StandardError) { def error_code = raise("broken reader") }
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        allow(provider).to receive(:init).and_raise(error_class.new("init failed"))

        expect do
          OpenFeature::SDK.set_provider_and_wait(provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        end
      end

      specify "Provider initialization errors should prevent the provider from being used" do
        # Store the old provider
        OpenFeature::SDK.provider

        # Create a provider that fails initialization
        failing_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        allow(failing_provider).to receive(:init).and_raise("Init failed")

        # Try to set the failing provider
        expect do
          OpenFeature::SDK.set_provider_and_wait(failing_provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError)

        # The failing provider should remain in place (with error state)
        expect(OpenFeature::SDK.provider).to eq(failing_provider)
      end
    end
  end

  context "2.2 - Flag Value Resolution" do
    context "Requirement 2.2.7" do
      let(:raising_provider_class) do
        Class.new do
          def initialize(error)
            @error = error
          end

          def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
            raise @error
          end
        end
      end

      after { OpenFeature::SDK.configuration.send(:reset) }

      def fetch_with(error, with_hook:)
        OpenFeature::SDK.set_provider_and_wait(raising_provider_class.new(error))
        client = OpenFeature::SDK.build_client
        client.hooks << Class.new { include OpenFeature::SDK::Hooks::Hook }.new if with_hook
        client.fetch_boolean_details(flag_key: "flag", default_value: false)
      end

      [false, true].each do |with_hook|
        context(with_hook ? "with a hook registered" : "without hooks") do
          specify "a provider raising EvaluationError reports its error code and message" do
            error = OpenFeature::SDK::EvaluationError.new("missing", error_code: OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
            details = fetch_with(error, with_hook:)

            expect(details.error_code).to eq("FLAG_NOT_FOUND")
            expect(details.error_message).to eq("missing")
            expect(details.reason).to eq("ERROR")
            expect(details.value).to be(false)
          end

          specify "an exception whose error_code reader raises reports GENERAL instead of escaping" do
            error_class = Class.new(StandardError) { def error_code = raise("broken reader") }

            expect(fetch_with(error_class.new("bad"), with_hook:).error_code).to eq("GENERAL")
          end
        end
      end
    end
  end

  context "2.3 - Provider hooks" do
    context "Requirement 2.3.2" do
      specify "In cases of normal execution, the built-in providers MUST NOT populate the error message field." do
        noop = OpenFeature::SDK::Provider::NoOpProvider.new
        {boolean: true, string: "s", number: 1, integer: 1, float: 1.0, object: {}}.each do |type, default_value|
          expect(noop.send(:"fetch_#{type}_value", flag_key: "k", default_value:).error_message).to be_nil
        end

        flag = OpenFeature::SDK::Provider::InMemoryProvider::Flag
        flags = {
          "plain" => true,
          "callable" => ->(_ctx) { true },
          "variant" => flag.new(variants: {"on" => true}, default_variant: "on"),
          "targeted" => flag.new(variants: {"on" => true, "off" => false}, default_variant: "off", context_evaluator: ->(_ctx) { "on" }),
          "disabled" => flag.new(variants: {"on" => true}, default_variant: "on", disabled: true)
        }
        in_memory = OpenFeature::SDK::Provider::InMemoryProvider.new(flags)
        flags.each_key do |flag_key|
          expect(in_memory.fetch_boolean_value(flag_key:, default_value: false).error_message).to be_nil
        end
      end
    end
  end

  context "2.8 - Provider status" do
    before { OpenFeature::SDK.configuration.send(:reset) }
    after { OpenFeature::SDK.configuration.send(:reset) }

    def marker_provider(&body)
      Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
        define_method(:emits_lifecycle_events?) { true }
        define_method(:init) { |_evaluation_context = nil| instance_exec(&body) }
      end.new
    end

    def calls_for(event_type)
      calls = []
      OpenFeature::SDK.add_handler(event_type, ->(details) { calls << details })
      calls
    end

    def state_of(provider) = OpenFeature::SDK.configuration.provider_state(provider)

    context "Requirement 2.8.2 / 2.8.3" do
      specify "2.8.2: the SDK doesn't synthesize READY for a provider that emits its own" do
        ready_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        provider = marker_provider { emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }

        OpenFeature::SDK.set_provider_and_wait(provider)

        expect(ready_calls.size).to eq(1)
        expect(state_of(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "2.8.3: the SDK doesn't synthesize ERROR for a provider that emits its own" do
        error_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR)
        provider = marker_provider do
          emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, error_code: OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL)
          raise "init failed"
        end

        expect { OpenFeature::SDK.set_provider_and_wait(provider) }.to raise_error(OpenFeature::SDK::ProviderInitializationError)
        expect(error_calls.size).to eq(1)
        expect(state_of(provider)).to eq(OpenFeature::SDK::ProviderState::FATAL)
      end

      specify "Appendix E: a marker provider's status comes only from its events" do
        provider = marker_provider {}

        OpenFeature::SDK.set_provider_and_wait(provider)

        expect(state_of(provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
      end
    end

    context "Condition 2.8.5" do
      specify "2.8.5.1: a provider without init is READY when set_provider returns" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new
        expect(Thread).not_to receive(:new)

        OpenFeature::SDK.set_provider(provider)

        expect(state_of(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "2.8.5.1: READY handlers run for a provider without init" do
        ready_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        expect(Thread).not_to receive(:new)

        OpenFeature::SDK.set_provider(OpenFeature::SDK::Provider::InMemoryProvider.new)

        expect(ready_calls.size).to eq(1)
      end

      specify "InMemoryProvider has no init" do
        expect(OpenFeature::SDK::Provider::InMemoryProvider.new).not_to respond_to(:init)
      end
    end

    context "Appendix E: legacy, marker and init-less providers" do
      let(:legacy_class) { Class.new(OpenFeature::SDK::Provider::InMemoryProvider) { def init(_evaluation_context = nil) = nil } }

      after { OpenFeature::SDK.configuration.logger = nil }

      specify "Appendix E: a legacy provider logs a deprecation warning once per class" do
        logger = spy("Logger")
        OpenFeature::SDK.configuration.logger = logger

        OpenFeature::SDK.set_provider_and_wait(legacy_class.new, domain: "a")
        OpenFeature::SDK.set_provider_and_wait(legacy_class.new, domain: "b")
        OpenFeature::SDK.set_provider_and_wait(marker_provider { emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }, domain: "c")
        OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new, domain: "d")

        expect(logger).to have_received(:warn).with(/deprecated/).once
      end

      specify "Appendix E: a legacy provider still gets synthetic READY" do
        ready_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)

        OpenFeature::SDK.set_provider_and_wait(legacy_class.new)

        expect(ready_calls.size).to eq(1)
      end

      specify "re-binding a marker provider to another domain sends no READY" do
        ready_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        provider = marker_provider { emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }

        OpenFeature::SDK.set_provider_and_wait(provider, domain: "a")
        expect(ready_calls.size).to eq(1)
        OpenFeature::SDK.set_provider_and_wait(provider, domain: "b")

        expect(ready_calls.size).to eq(1)
      end

      specify "2.8.5.1: binding a provider without init to another domain runs that domain's READY handlers" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        domain_b_ready = 0
        OpenFeature::SDK.build_client(domain: "b").add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(_details) { domain_b_ready += 1 })

        OpenFeature::SDK.set_provider(provider, domain: "a")
        OpenFeature::SDK.set_provider(provider, domain: "b")

        expect(domain_b_ready).to eq(1)
      end

      specify "re-binding a provider without init to the same domain sends no duplicate READY" do
        ready_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider_and_wait(provider)
        OpenFeature::SDK.set_provider_and_wait(provider)

        expect(ready_calls.size).to eq(1)
      end

      specify "2.8.5.1: a provider without init is READY even if it declares the marker" do
        ready_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        provider = Class.new(OpenFeature::SDK::Provider::NoOpProvider) { def emits_lifecycle_events? = true }.new

        OpenFeature::SDK.set_provider(provider)

        expect(state_of(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
        expect(ready_calls.size).to eq(1)
      end

      specify "1.1.2.4: re-initializing a marker provider from one of its own handlers returns with it READY" do
        outcomes = Queue.new
        provider = marker_provider do
          if outcomes.pop == :fail
            emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, message: "init failed")
            raise "init failed"
          end
          emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        end
        outcomes << :fail
        expect { OpenFeature::SDK.set_provider_and_wait(provider) }.to raise_error(OpenFeature::SDK::ProviderInitializationError)
        state_after_retry = nil
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, lambda do |_details|
          OpenFeature::SDK.set_provider_and_wait(provider)
          state_after_retry = state_of(provider)
        end)
        outcomes << :ok

        provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

        expect(state_after_retry).to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "re-binding a legacy provider to another domain still sends READY" do
        ready_calls = calls_for(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        provider = legacy_class.new

        OpenFeature::SDK.set_provider_and_wait(provider, domain: "a")
        OpenFeature::SDK.set_provider_and_wait(provider, domain: "b")

        expect(ready_calls.size).to eq(2)
      end
    end
  end
end
