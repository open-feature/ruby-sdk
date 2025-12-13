# frozen_string_literal: true

require "spec_helper"
require "open_feature/sdk/provider/no_op_provider"
require "open_feature/sdk/provider/in_memory_provider"

RSpec.describe "Providers Without Event Capabilities" do
  describe "NoOpProvider without event capabilities" do
    let(:provider) { OpenFeature::SDK::Provider::NoOpProvider.new }

    it "continues to work without implementing new interfaces" do
      expect { provider.fetch_boolean_value(flag_key: "test", default_value: true) }.not_to raise_error
    end

    it "does not respond to new interface methods" do
      expect(provider).not_to respond_to(:attach)
      expect(provider).not_to respond_to(:detach)
      expect(provider).not_to respond_to(:emit_event)
    end

    it "does not respond to init or shutdown" do
      expect(provider).not_to respond_to(:init)
      expect(provider).not_to respond_to(:shutdown)
    end
  end

  describe "InMemoryProvider without event capabilities" do
    let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

    it "continues to work with existing init/shutdown methods" do
      expect { provider.init }.not_to raise_error
      expect { provider.shutdown }.not_to raise_error
    end

    it "does not automatically gain event capabilities" do
      expect(provider).not_to respond_to(:attach)
      expect(provider).not_to respond_to(:emit_event)
    end

    it "fetch methods continue to work" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new(
        "test-flag" => true
      )

      result = provider.fetch_boolean_value(flag_key: "test-flag", default_value: false)
      expect(result.value).to be true
    end
  end
end

RSpec.describe "Mixed Provider Usage" do
  it "can use different provider types together" do
    noop_provider = OpenFeature::SDK::Provider::NoOpProvider.new
    inmemory_provider = OpenFeature::SDK::Provider::InMemoryProvider.new

    # Both should work for fetching values
    noop_result = noop_provider.fetch_string_value(flag_key: "test", default_value: "noop")
    inmemory_result = inmemory_provider.fetch_string_value(flag_key: "test", default_value: "memory")

    expect(noop_result.value).to eq("noop")
    expect(inmemory_result.value).to eq("memory")
  end
end

RSpec.describe "Provider Interface Detection" do
  # Create a test provider that implements the new interfaces
  let(:event_capable_provider) do
    Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
      include OpenFeature::SDK::Provider::EventHandler
    end.new
  end

  it "can check if provider implements lifecycle methods using duck typing" do
    noop_provider = OpenFeature::SDK::Provider::NoOpProvider.new
    inmemory_provider = OpenFeature::SDK::Provider::InMemoryProvider.new

    # Check using respond_to? (Ruby way)
    expect(noop_provider.respond_to?(:init)).to be false
    expect(inmemory_provider.respond_to?(:init)).to be true
  end

  it "can check if provider implements EventHandler" do
    noop_provider = OpenFeature::SDK::Provider::NoOpProvider.new

    # Check using is_a? with module
    expect(noop_provider.class.included_modules).not_to include(OpenFeature::SDK::Provider::EventHandler)
    expect(event_capable_provider.class.included_modules).to include(OpenFeature::SDK::Provider::EventHandler)
  end
end
