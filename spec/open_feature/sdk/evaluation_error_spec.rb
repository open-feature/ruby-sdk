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

  describe ".code_for" do
    it "returns the code of any exception exposing error_code" do
      error = Class.new(StandardError) { def error_code = "PARSE_ERROR" }.new

      expect(described_class.code_for(error)).to eq("PARSE_ERROR")
    end

    it "returns GENERAL when the exception has no error_code" do
      expect(described_class.code_for(StandardError.new)).to eq("GENERAL")
    end

    it "returns GENERAL when error_code is nil" do
      error = Class.new(StandardError) { def error_code = nil }.new

      expect(described_class.code_for(error)).to eq("GENERAL")
    end

    it "returns GENERAL when the error_code reader raises" do
      error = Class.new(StandardError) { def error_code = raise("broken reader") }.new

      expect(described_class.code_for(error)).to eq("GENERAL")
    end
  end
end
