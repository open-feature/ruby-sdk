# frozen_string_literal: true

require_relative "../../spec_helper"

require "openfeature/sdk/configuration"
require "openfeature/sdk/api"
require "openfeature/sdk/metadata"

# https://docs.openfeature.dev/docs/specification/sections/flag-evaluation#11-api-initialization-and-configuration

RSpec.describe OpenFeature::SDK::API do
  subject(:api) { described_class.instance }

  context "with Requirement 1.1.2" do
    before do
      api.configure do |config|
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
      end
    end

    it do
      expect(api).to respond_to(:provider)
    end

    it do
      expect(api.provider).not_to be_nil
    end

    it do
      expect(api.provider).is_a?(OpenFeature::SDK::Provider)
    end
  end

  context "with Requirement 1.1.3" do
    before do
      api.configure do |config|
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
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
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
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
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
      end

      api.build_client(name: "requirement-1.1.5")
    end

    it "provide a function for creating a client which accepts the following options: * name (optional): A logical string identifier for the client." do
      expect(api).to respond_to(:build_client).with_keywords(:name, :version)
    end

    it do
      expect(api).is_a?(OpenFeature::SDK::Client)
    end
  end
end
