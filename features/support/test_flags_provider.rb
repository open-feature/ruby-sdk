# frozen_string_literal: true

# Test-only provider that loads the spec's test-flags.json and resolves flags
# using variants, defaultVariant, contextEvaluator, flagMetadata, and disabled.
class TestFlagsProvider
  include OpenFeature::SDK::Provider::EventEmitter

  NAME = "Test Flags Provider"

  attr_reader :metadata

  def initialize(flags)
    @flags = flags
    @metadata = OpenFeature::SDK::Provider::ProviderMetadata.new(name: NAME).freeze
    @cache = {}
  end

  def init(evaluation_context = nil)
    # no-op
  end

  def shutdown
    # no-op
  end

  %w[boolean string number integer float object].each do |type|
    define_method(:"fetch_#{type}_value") do |flag_key:, default_value:, evaluation_context: nil|
      resolve(flag_key, default_value, evaluation_context)
    end
  end

  private

  def resolve(flag_key, default_value, evaluation_context)
    flag = @flags[flag_key]

    unless flag
      return OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: default_value,
        error_code: OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND,
        reason: OpenFeature::SDK::Provider::Reason::ERROR
      )
    end

    if flag["disabled"]
      return OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: default_value,
        reason: OpenFeature::SDK::Provider::Reason::DISABLED
      )
    end

    default_variant_key = flag["defaultVariant"]
    variants = flag["variants"] || {}
    flag_metadata = build_flag_metadata(flag["flagMetadata"])
    context_evaluator = flag["contextEvaluator"]

    # Handle null/missing defaultVariant
    unless default_variant_key && variants.key?(default_variant_key)
      return OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: default_value,
        error_code: OpenFeature::SDK::Provider::ErrorCode::PARSE_ERROR,
        reason: OpenFeature::SDK::Provider::Reason::ERROR,
        flag_metadata: flag_metadata
      )
    end

    if context_evaluator
      resolve_with_targeting(flag, default_value, evaluation_context, flag_metadata)
    else
      # Check cache for CACHED reason support
      cache_key = flag_key_for_cache(flag, default_value)
      if @cache.key?(cache_key)
        return OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: variants[default_variant_key],
          variant: default_variant_key,
          reason: OpenFeature::SDK::Provider::Reason::CACHED,
          flag_metadata: flag_metadata
        )
      end

      @cache[cache_key] = true

      OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: variants[default_variant_key],
        variant: default_variant_key,
        reason: OpenFeature::SDK::Provider::Reason::STATIC,
        flag_metadata: flag_metadata
      )
    end
  end

  def resolve_with_targeting(flag, default_value, evaluation_context, flag_metadata)
    variants = flag["variants"]
    default_variant_key = flag["defaultVariant"]
    expression = flag["contextEvaluator"]

    matched_variant = evaluate_expression(expression, evaluation_context)

    if matched_variant && !matched_variant.empty? && variants.key?(matched_variant)
      OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: variants[matched_variant],
        variant: matched_variant,
        reason: OpenFeature::SDK::Provider::Reason::TARGETING_MATCH,
        flag_metadata: flag_metadata
      )
    else
      OpenFeature::SDK::Provider::ResolutionDetails.new(
        value: variants[default_variant_key],
        variant: default_variant_key,
        reason: OpenFeature::SDK::Provider::Reason::DEFAULT,
        flag_metadata: flag_metadata
      )
    end
  end

  # Evaluates the limited CEL-like expressions from test-flags.json.
  # Known patterns:
  #   "email == 'ballmer@macrosoft.com' ? 'zero' : ''"
  #   "!customer && email == 'ballmer@macrosoft.com' && age > 10 ? 'internal' : ''"
  def evaluate_expression(expression, evaluation_context)
    return "" unless evaluation_context

    ctx = context_to_hash(evaluation_context)

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

  def context_to_hash(evaluation_context)
    return {} unless evaluation_context

    evaluation_context.fields.dup
  end

  def build_flag_metadata(raw_metadata)
    return nil if raw_metadata.nil?

    raw_metadata.freeze
  end

  def flag_key_for_cache(flag, default_value)
    flag.object_id
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
