# frozen_string_literal: true

require "spec_helper"

# https://openfeature.dev/docs/specification/sections/flag-evaluation#11-api-initialization-and-configuration

RSpec.describe OpenFeature::SDK::API do
  subject(:api) { described_class.instance }

  context "with Requirement 1.1.3" do
    before do
      api.configure do |config|
        config.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new)
        config.hooks << hook1
        config.hooks << hook2
      end
    end

    let(:hook1) { "my_hook" }
    let(:hook2) { "my_other_hook" }

    it do
      expect(api).to respond_to(:hooks)
      expect(api.hooks).to have_attributes(size: 2).and eq([hook1, hook2])
    end
  end

  context "with Requirement 1.1.4" do
    before do
      api.configure do |config|
        config.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new)
      end
    end

    it "must provide a function for retrieving the metadata field of the configured provider" do
      expect(api.provider.metadata).not_to be_nil
    end

    it do
      expect(api.provider).to respond_to(:metadata)
    end

    it do
      expect(api.provider.metadata).is_a?(OpenFeature::SDK::Metadata)
    end

    it do
      expect(api.provider.metadata).to eq(OpenFeature::SDK::Metadata.new(name: OpenFeature::SDK::Provider::NoOpProvider::NAME))
    end
  end

  context "with Requirement 1.1.5" do
    before do
      api.configure do |config|
        config.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new)
      end

      api.build_client
    end

    it "provide a function for creating a client which accepts the following options: * name (optional): A logical string identifier for the client." do
      expect(api).to respond_to(:build_client).with_keywords(:name, :version)
    end

    it do
      expect(api).is_a?(OpenFeature::SDK::Client)
    end
  end

  context "with Requirement 1.1.6" do
    pending
  end

  context "when domain is given" do
    it "can generate a client both with and without that domain" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new

      api.configure do |config|
        config.set_provider(provider, domain: "testing1")
      end

      client = api.build_client(domain: "testing1")
      no_domain_client = api.build_client

      expect(client.provider).to be(provider)
      expect(no_domain_client.provider).to be_an_instance_of(OpenFeature::SDK::Provider::NoOpProvider)
    end
  end

  context "when domain is not provided" do
    it "can generate a client without a domain properly" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new

      api.configure do |config|
        config.set_provider(provider)
      end

      no_domain_client = api.build_client

      expect(no_domain_client.provider).to be(provider)
    end

    it "can generate a client with a domain properly" do
      api.configure do |config|
        config.set_provider(OpenFeature::SDK::Provider::InMemoryProvider.new)
      end

      domain_client = api.build_client(domain: "testing2")
      # This domain was never given a provider, so it should default to the NoOpProvider
      expect(domain_client.provider).to be_an_instance_of(OpenFeature::SDK::Provider::NoOpProvider)
    end
  end
end
