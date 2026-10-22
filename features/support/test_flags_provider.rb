# frozen_string_literal: true

# Converts the spec's test-flags.json into InMemoryProvider flags, so the
# gherkin suite runs on the SDK's in-memory provider (spec Appendix A).
def build_test_flags(json)
  json.to_h do |key, flag|
    expression = flag["contextEvaluator"]
    in_memory_flag = OpenFeature::SDK::Provider::InMemoryProvider::Flag.new(
      variants: flag["variants"],
      default_variant: flag["defaultVariant"],
      context_evaluator: expression && ->(evaluation_context) { evaluate_test_flag_expression(expression, evaluation_context) },
      flag_metadata: flag["flagMetadata"]&.freeze,
      disabled: flag["disabled"]
    )
    [key, in_memory_flag]
  end
end

# Evaluates the limited CEL-like expressions from test-flags.json.
# Known patterns:
#   "email == 'ballmer@macrosoft.com' ? 'zero' : ''"
#   "!customer && email == 'ballmer@macrosoft.com' && age > 10 ? 'internal' : ''"
def evaluate_test_flag_expression(expression, evaluation_context)
  return "" unless evaluation_context

  ctx = evaluation_context.fields.dup

  case expression
  when /\A(\w+)\s*==\s*'([^']*)'\s*\?\s*'([^']*)'\s*:\s*'([^']*)'\z/
    field, expected, if_true, if_false = $1, $2, $3, $4
    (ctx[field].to_s == expected) ? if_true : if_false
  when /\A!(\w+)\s*&&\s*(\w+)\s*==\s*'([^']*)'\s*&&\s*(\w+)\s*>\s*(\d+)\s*\?\s*'([^']*)'\s*:\s*'([^']*)'\z/
    bool_field, str_field, str_val, num_field, num_val, if_true, if_false = $1, $2, $3, $4, $5.to_i, $6, $7
    bool_val = ctx[bool_field]
    is_falsy = bool_val.nil? || bool_val == false || bool_val == "false"
    str_match = ctx[str_field].to_s == str_val
    num_match = ctx[num_field].to_i > num_val
    (is_falsy && str_match && num_match) ? if_true : if_false
  else
    ""
  end
end

# The in-memory provider has no cache; this test-only subclass reports a repeat
# static resolution of the same flag as CACHED for the @reason-codes-cached scenario.
class CachingInMemoryProvider < OpenFeature::SDK::Provider::InMemoryProvider
  def initialize(flags = {})
    super
    @resolved = {}
  end

  private

  def fetch_value(flag_key:, default_value:, evaluation_context:)
    details = super
    return details unless details.reason == OpenFeature::SDK::Provider::Reason::STATIC

    details.reason = OpenFeature::SDK::Provider::Reason::CACHED if @resolved[flag_key]
    @resolved[flag_key] = true
    details
  end
end

# A provider that captures the merged evaluation context for assertion.
# Used by context merging tests.
class ContextCapturingProvider
  include OpenFeature::SDK::Provider::EventEmitter

  NAME = "Context Capturing Provider"

  attr_reader :metadata, :last_context

  def initialize
    @metadata = OpenFeature::SDK::Provider::ProviderMetadata.new(name: NAME).freeze
    @last_context = nil
  end

  def init(evaluation_context = nil)
    # no-op
  end

  def shutdown
    # no-op
  end

  %w[boolean string number integer float object].each do |type|
    define_method(:"fetch_#{type}_value") do |flag_key:, default_value:, evaluation_context: nil|
      @last_context = evaluation_context
      OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: default_value,
        reason: OpenFeature::SDK::Provider::Reason::STATIC
      )
    end
  end
end

# A provider that stays in a specified state for provider status tests.
class StatusProvider
  NAME = "Status Provider"

  attr_reader :metadata

  def initialize(name: NAME)
    @metadata = OpenFeature::SDK::Provider::ProviderMetadata.new(name: name).freeze
  end

  %w[boolean string number integer float object].each do |type|
    define_method(:"fetch_#{type}_value") do |flag_key:, default_value:, evaluation_context: nil|
      OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: default_value,
        reason: OpenFeature::SDK::Provider::Reason::ERROR,
        error_code: OpenFeature::SDK::Provider::ErrorCode::GENERAL
      )
    end
  end
end
