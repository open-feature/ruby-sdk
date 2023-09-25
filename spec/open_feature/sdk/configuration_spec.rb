# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Configuration do
  subject(:configuration) { described_class.new }

  describe "#provider=" do
    context "when provider has an init method" do
      let(:provider) { TestProvider.new }

      it "inits and sets the provider" do
        expect(provider).to receive(:init)

        configuration.set_provider(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when provider does not have an init method" do
      it "sets the provider" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        configuration.set_provider(provider)

        expect(configuration.provider).to be(provider)
      end
    end
  end
end
