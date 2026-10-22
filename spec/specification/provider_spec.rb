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

      specify "Requirement 2.4.5: Provider status indicates FATAL if init terminates with PROVIDER_FATAL error code" do
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

      specify "Requirement 2.4.5: Provider status indicates ERROR for non-fatal init errors" do
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
end
