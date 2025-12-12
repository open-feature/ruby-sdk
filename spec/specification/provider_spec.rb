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
          include OpenFeature::SDK::Provider::EventHandler

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
end
