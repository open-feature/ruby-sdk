# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Flag Evaluation API" do
  context "1.1 - API Initialization and Configuration" do
    context "Requirement 1.1.1" do
      specify "the API should exist as a global singleton" do
        expect(OpenFeature::SDK::API).to include(Singleton)
      end
    end
  end
end
