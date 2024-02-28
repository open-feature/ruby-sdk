# frozen_string_literal: true

require "spec_helper"
require_relative "../support/test_provider"

RSpec.describe "Flag Evaluation API" do
  context "1.1 - API Initialization and Configuration" do
    context "Requirement 1.1.1" do
      specify "the API should exist as a global singleton" do
        expect(OpenFeature::SDK::API).to include(Singleton)
      end
    end

    context "Requirement 1.1.2.1" do
      specify "the API must define a provider mutator" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        OpenFeature::SDK.set_provider(provider)

        expect(OpenFeature::SDK.provider).to be(provider)
      end
    end

    context "Requirement 1.1.2.2" do
      specify "the provider mutator must invoke an initialize function on the provider" do
        provider = TestProvider.new
        expect(provider).to receive(:init)

        OpenFeature::SDK.set_provider(provider)
      end
    end

    context "Requirement 1.1.2.3" do
      specify "the provider mutator must invoke a shutdown function on previously registered provider" do
        previous_provider = TestProvider.new
        new_provider = TestProvider.new

        expect(previous_provider).to receive(:shutdown)
        expect(new_provider).not_to receive(:shutdown)

        OpenFeature::SDK.set_provider(previous_provider)
        OpenFeature::SDK.set_provider(new_provider)
      end
    end

    context "Requirement 1.1.3" do
      specify "the API must provide a function to bind a given provider to one or more client names" do
        first_provider = TestProvider.new
        second_provider = TestProvider.new

        OpenFeature::SDK.set_provider(first_provider, domain: "first")
        OpenFeature::SDK.set_provider(second_provider, domain: "second")

        expect(OpenFeature::SDK.provider(domain: "first")).to be(first_provider)
        expect(OpenFeature::SDK.provider(domain: "second")).to be(second_provider)
      end

      specify "if client name is already bound, it is overwritten" do
        previous_provider = TestProvider.new
        new_provider = TestProvider.new

        OpenFeature::SDK.set_provider(previous_provider, domain: "testing")
        expect(OpenFeature::SDK.provider(domain: "testing")).to be(previous_provider)

        OpenFeature::SDK.set_provider(new_provider, domain: "testing")
        expect(OpenFeature::SDK.provider(domain: "testing")).to be(new_provider)
      end
    end
  end
end
