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

    context "when domain is given" do
      it "binds the provider to that domain" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        expect(provider).to receive(:init)

        configuration.set_provider(provider, domain: "testing")

        expect(configuration.provider(domain: "testing")).to be(provider)
      end
    end

    context "when the provider is set concurrently" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
      it "does not not call shutdown hooks multiple times if multithreaded" do
        providers = (0..2).map { OpenFeature::SDK::Provider::NoOpProvider.new }
        providers.each { |provider| expect(provider).to receive(:init) }
        providers[0, 2].each { |provider| expect(provider).to receive(:shutdown) }
        configuration.set_provider(providers[0])

        allow(providers[0]).to receive(:shutdown).once { sleep 0.5 }
        background { configuration.set_provider(providers[1]) }
        background { configuration.set_provider(providers[2]) }
        yield_to_background
        expect(configuration.provider).to be(providers[2])
      end
    end
  end
end
