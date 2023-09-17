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
        provider = double
        expect(provider).to receive(:init)

        OpenFeature::SDK.set_provider(provider)
      end
    end
  end
end
