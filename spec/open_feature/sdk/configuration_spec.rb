# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Configuration do
  subject(:configuration) { described_class.new }

  describe "#set_provider" do
    context "when provider has an init method" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      it "inits and sets the provider" do
        expect(provider).to receive(:init)

        configuration.set_provider(provider)

        expect(configuration.provider).to be(provider)
        
        # Wait for async initialization
        sleep(0.1)
      end
    end

    context "when provider does not have an init method" do
      it "sets the default provider" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        configuration.set_provider(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when domain is given" do
      it "binds the provider to that domain" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        expect(provider).to receive(:init)

        configuration.set_provider(provider, domain: "testing")

        expect(configuration.provider(domain: "testing")).to be(provider)
        
        # Wait for async initialization
        sleep(0.1)
      end
    end

    context "when the provider is set concurrently" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
      it "does not not call shutdown hooks multiple times if multithreaded" do
        providers = (0..2).map { OpenFeature::SDK::Provider::NoOpProvider.new }
        providers.each { |provider| allow(provider).to receive(:init) }
        providers[0, 2].each { |provider| allow(provider).to receive(:shutdown) }
        configuration.set_provider(providers[0])

        allow(providers[0]).to(receive(:shutdown).once { sleep 0.5 })
        background { configuration.set_provider(providers[1]) }
        background { configuration.set_provider(providers[2]) }
        yield_to_background
        expect(configuration.provider).to be(providers[2])
      end
    end
  end

  describe "#set_provider_and_wait" do
    context "when provider has a successful init method" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      it "waits for init to complete and sets the provider" do
        expect(provider).to receive(:init).once

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end

      it "supports custom timeout" do
        expect(provider).to receive(:init).once

        configuration.set_provider_and_wait(provider, timeout: 60)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when provider does not have an init method" do
      it "sets the provider without waiting" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when domain is given" do
      it "binds the provider to that domain" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        expect(provider).to receive(:init).once

        configuration.set_provider_and_wait(provider, domain: "testing")

        expect(configuration.provider(domain: "testing")).to be(provider)
      end
    end

    context "when provider init raises an exception" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
      let(:error_message) { "Database connection failed" }

      before do
        allow(provider).to receive(:init).and_raise(StandardError.new(error_message))
      end

      it "raises ProviderInitializationError" do
        expect do
          configuration.set_provider_and_wait(provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include("Provider initialization failed")
          expect(error.message).to include(error_message)
          expect(error.provider).to be(provider)
          expect(error.original_error).to be_a(StandardError)
          expect(error.original_error.message).to eq(error_message)
          expect(error.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL)
        end
      end

      it "does not set the provider when init fails" do
        old_provider = configuration.provider

        expect do
          configuration.set_provider_and_wait(provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError)

        expect(configuration.provider).to be(old_provider)
      end
    end

    context "when provider init times out" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      before do
        allow(provider).to receive(:init) do
          sleep 2 # Simulate slow initialization
        end
      end

      it "raises ProviderInitializationError after timeout" do
        expect do
          configuration.set_provider_and_wait(provider, timeout: 0.1)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include("Provider initialization timed out after 0.1 seconds")
          expect(error.provider).to be(provider)
          expect(error.original_error).to be_a(Timeout::Error)
          expect(error.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL)
        end
      end

      it "does not set the provider when init times out" do
        old_provider = configuration.provider

        expect do
          configuration.set_provider_and_wait(provider, timeout: 0.1)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError)

        expect(configuration.provider).to be(old_provider)
      end
    end

    context "when shutting down the old provider fails" do
      let(:old_provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
      let(:new_provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      before do
        # Set up initial provider
        configuration.set_provider(old_provider)
        allow(old_provider).to receive(:shutdown).and_raise(StandardError.new("Shutdown failed"))
        allow(new_provider).to receive(:init)
      end

      it "continues with setting the new provider" do
        # Should not raise an exception even if shutdown fails
        configuration.set_provider_and_wait(new_provider)

        expect(configuration.provider).to be(new_provider)
      end
    end

    context "when the provider is set concurrently" do
      let(:providers) { (0..2).map { OpenFeature::SDK::Provider::InMemoryProvider.new } }

      it "handles concurrent calls safely" do
        providers.each { |provider| expect(provider).to receive(:init).once }
        # First two providers should be shut down
        expect(providers[0]).to receive(:shutdown).once
        expect(providers[1]).to receive(:shutdown).once

        configuration.set_provider_and_wait(providers[0])

        # Simulate slow initialization for concurrent testing
        allow(providers[0]).to receive(:shutdown) { sleep 0.1 }

        background { configuration.set_provider_and_wait(providers[1]) }
        background { configuration.set_provider_and_wait(providers[2]) }
        yield_to_background

        # The last provider should be set
        expect(configuration.provider).to be(providers[2])
      end
    end

    context "when handling complex initialization scenarios" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      it "handles provider that responds_to init but init is nil" do
        allow(provider).to receive(:respond_to?).with(:init).and_return(true)
        allow(provider).to receive(:init).and_return(nil)

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end
      
      it "handles setting provider to a domain with no previous provider" do
        # This should not raise any errors even though old_provider will be nil
        expect { configuration.set_provider_and_wait(provider, domain: "new-domain") }.not_to raise_error
        
        expect(configuration.provider(domain: "new-domain")).to be(provider)
      end
    end
  end
end
