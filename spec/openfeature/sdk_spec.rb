# frozen_string_literal: true

RSpec.describe OpenFeature::SDK do
  it "has a version number" do
    expect(OpenFeature::SDK::VERSION).not_to be_nil
  end
end
