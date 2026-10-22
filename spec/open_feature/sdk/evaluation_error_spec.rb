# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::EvaluationError do
  it "carries the message and error code it was given" do
    error = described_class.new("boom", error_code: "FLAG_NOT_FOUND")

    expect(error.message).to eq("boom")
    expect(error.error_code).to eq("FLAG_NOT_FOUND")
  end

  it "uses the error code as the message when none is given" do
    expect(described_class.new(error_code: "PARSE_ERROR").message).to eq("PARSE_ERROR")
  end

  it "defaults the error code to GENERAL" do
    expect(described_class.new("x").error_code).to eq("GENERAL")
  end
end
