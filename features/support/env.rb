# frozen_string_literal: true

require "json"
require "open_feature/sdk"

GHERKIN_DIR = File.expand_path("../../spec/open-feature-spec/specification/assets/gherkin", __dir__)
TEST_FLAGS = JSON.parse(File.read(File.join(GHERKIN_DIR, "test-flags.json")))

require_relative "test_flags_provider"

Before do
  OpenFeature::SDK.configure do |config|
    config.hooks = []
    config.evaluation_context = nil
    config.transaction_context_propagator = nil
  end
  @context = nil
  @evaluation_details = nil
end

After do
  OpenFeature::SDK.shutdown
end
