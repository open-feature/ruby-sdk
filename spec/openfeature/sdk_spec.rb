# frozen_string_literal: true

require_relative "../spec_helper"

require_relative "../../lib/openfeature/sdk/provider/no_op_provider"
require_relative "../../lib/openfeature/sdk/configuration"
require_relative "../../lib/openfeature/sdk"
require_relative "../../lib/openfeature/sdk/metadata"

RSpec.describe OpenFeature::SDK do
  before do
    subject
  end

  context "Requirement 1.1.2" do
    subject do
      OpenFeature::SDK.configure do |config|
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
      end
    end

    it "must provide a function to set the global provider singleton, which accepts an API-conformant provider implementation" do
      expect(OpenFeature::SDK).to respond_to(:provider)
      expect(OpenFeature::SDK.provider).not_to be_nil
      expect(OpenFeature::SDK.provider).is_a?(OpenFeature::SDK::Provider)
    end
  end

  context "Requirement 1.1.3" do
    subject do
      OpenFeature::SDK.configure do |config|
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
        config.hooks << hook_1
        config.hooks << hook_2
      end
    end

    let(:hook1) do
      Class.new do
        include Hook
      end
    end
    let(:hook2) do
      Class.new do
        include Hook
      end
    end

    it "must provide a function that adds hooks which accepts one or more API-conformant `hooks`, and appends them to the collection of any previously added hooks. When new hooks are added, previously added hooks are not removed." do
      expect(OpenFeature::SDK).to respond_to(:hooks)
      expect(OpenFeature::SDK.hooks).to have_attributes(size: 2).and eq([hook1, hook2])
    end
  end

  context "Requirement 1.1.4" do
    subject do
      OpenFeature::SDK.configure do |config|
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
      end
    end

    it "must provide a function for retrieving the metadata field of the configured provider" do
      expect(OpenFeature::SDK.provider.metadata).not_to be_nil
      expect(OpenFeature::SDK.provider).to respond_to(:metadata)
      expect(OpenFeature::SDK.provider.metadata).is_a?(OpenFeature::SDK::Metadata)

      expect(OpenFeature::SDK.provider.metadata).to eq(OpenFeature::SDK::Metadata.new(name: OpenFeature::SDK::Provider::NoOpProvider::NAME))
    end
  end

  context "Requirement 1.1.5" do
    subject do
      OpenFeature::SDK.configure do |config|
        config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
      end

      OpenFeature::SDK.build_client(name: "requirement-1.1.5")
    end

    it "provide a function for creating a client which accepts the following options: * name (optional): A logical string identifier for the client." do
      expect(OpenFeature::SDK).to respond_to(:build_client).with(1).arguments
      expect(subject).is_a?(OpenFeature::SDK::Client)
    end
  end
end
