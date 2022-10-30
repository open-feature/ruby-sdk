# frozen_string_literal: true

RSpec.describe OpenFeature::Sdk do
  it "has a version number" do
    expect(OpenFeature::Sdk::VERSION).not_to be nil
  end
end
