# frozen_string_literal: true

# Before hook that adds context entries for "Before Hooks" level testing
class ContextAddingBeforeHook
  include OpenFeature::SDK::Hooks::Hook

  attr_reader :context_entries

  def initialize
    @context_entries = {}
  end

  def add_entry(key, value)
    @context_entries[key] = value
  end

  def before(hook_context:, hints:)
    return nil if @context_entries.empty?

    OpenFeature::SDK::EvaluationContext.new(**@context_entries.transform_keys(&:to_sym))
  end
end

Given("a stable provider with retrievable context is registered") do
  @capturing_provider = ContextCapturingProvider.new
  OpenFeature::SDK.set_provider_and_wait(@capturing_provider)
  @context_hook = ContextAddingBeforeHook.new
  @invocation_context_entries = {}
  @client_context_entries = {}
end

Given("A context entry with key {string} and value {string} is added to the {string} level") do |key, value, level|
  case level
  when "API"
    existing = OpenFeature::SDK.evaluation_context
    new_fields = existing ? existing.fields.merge(key => value) : {key => value}
    OpenFeature::SDK.configure do |config|
      config.evaluation_context = OpenFeature::SDK::EvaluationContext.new(**new_fields.transform_keys(&:to_sym))
    end
  when "Transaction"
    propagator = OpenFeature::SDK.configuration.transaction_context_propagator
    unless propagator
      propagator = OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new
      OpenFeature::SDK.configure do |config|
        config.transaction_context_propagator = propagator
      end
    end
    existing = propagator.get_transaction_context
    new_fields = existing ? existing.fields.merge(key => value) : {key => value}
    propagator.set_transaction_context(
      OpenFeature::SDK::EvaluationContext.new(**new_fields.transform_keys(&:to_sym))
    )
  when "Client"
    @client_context_entries[key] = value
  when "Invocation"
    @invocation_context_entries[key] = value
  when "Before Hooks"
    @context_hook.add_entry(key, value)
  end
end

When("Some flag was evaluated") do
  client_context = unless @client_context_entries.empty?
    OpenFeature::SDK::EvaluationContext.new(**@client_context_entries.transform_keys(&:to_sym))
  end

  @client = OpenFeature::SDK.build_client(evaluation_context: client_context)
  @client.hooks = [@context_hook]

  invocation_context = unless @invocation_context_entries.empty?
    OpenFeature::SDK::EvaluationContext.new(**@invocation_context_entries.transform_keys(&:to_sym))
  end

  @client.fetch_boolean_value(
    flag_key: "boolean-flag",
    default_value: false,
    evaluation_context: invocation_context
  )
end

Then("The merged context contains an entry with key {string} and value {string}") do |key, value|
  merged = @capturing_provider.last_context
  expect(merged).not_to be_nil, "Expected merged context to be present"
  expect(merged.fields[key]).to eq(value), "Expected context[#{key}] = #{value}, got #{merged.fields[key].inspect}"
end

# -- Precedence table steps --

Given("A table with levels of increasing precedence") do |table|
  @precedence_levels = table.raw.flatten
end

Given("Context entries for each level from API level down to the {string} level, with key {string} and value {string}") do |target_level, key, value_template|
  @precedence_levels.each do |level|
    step_value = level
    step "A context entry with key \"#{key}\" and value \"#{step_value}\" is added to the \"#{level}\" level"
    break if level == target_level
  end
end
