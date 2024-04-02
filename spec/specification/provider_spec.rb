# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Provider" do
  context "2.1 - Feature Provider Interface" do
    context "Requirement 2.1.1" do
      specify "The provider interface MUST define a metadata member or accessor, containing a name field or accessor of type string, which identifies the provider implementation." do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        expect(provider.metadata.name).to eq("No-op Provider")
      end
    end
  end
end
