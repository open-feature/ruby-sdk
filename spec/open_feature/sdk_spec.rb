# frozen_string_literal: true

RSpec.describe OpenFeature::SDK do
  it "has a version number" do
    expect(OpenFeature::SDK::VERSION).not_to be_nil
  end

  it "can be configured" do
    expect(OpenFeature::SDK).to respond_to(:configure)

    OpenFeature::SDK.configure do |config|
      # don't test here, rely on OpenFeature::SDK::API instead
    end
  end

  describe "#set_provider_and_wait" do
    it "delegates to the API instance" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      api_instance = OpenFeature::SDK::API.instance

      expect(api_instance).to receive(:set_provider_and_wait).with(provider, domain: "test", timeout: 60)

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "test", timeout: 60)
    end

    it "is accessible via method_missing delegation" do
      expect(OpenFeature::SDK).to respond_to(:set_provider_and_wait)
    end

    it "works with basic provider initialization" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new

      expect do
        OpenFeature::SDK.set_provider_and_wait(provider)
      end.not_to raise_error

      # Clean up by setting back to NoOp provider
      OpenFeature::SDK.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new)
    end

    it "raises ProviderInitializationError when provider init fails" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_raise(StandardError.new("Init failed"))

      expect do
        OpenFeature::SDK.set_provider_and_wait(provider)
      end.to raise_error(OpenFeature::SDK::ProviderInitializationError, /Provider initialization failed/) do |error|
        expect(error.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL)
      end

      # Clean up
      OpenFeature::SDK.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new)
    end
  end
end
