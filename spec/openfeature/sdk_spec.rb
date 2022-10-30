# frozen_string_literal: true

RSpec.describe Openfeature::Sdk do
  it "has a version number" do
    expect(Openfeature::Sdk::VERSION).not_to be nil
  end
end
