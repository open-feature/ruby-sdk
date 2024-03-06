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
      end
    end

    context "when provider does not have an init method" do
      it "sets the default provider" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        configuration.set_provider(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when name is given" do
      it "binds the provider to that name" do
        provider = TestProvider.new
        expect(provider).to receive(:init)

        configuration.set_provider(provider, domain: "testing")

        expect(configuration.provider(domain: "testing")).to be(provider)
      end
    end
  end
end
