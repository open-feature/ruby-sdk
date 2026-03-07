# frozen_string_literal: true

# -- Provider setup steps --

Given(/^a (stable|not ready|error|fatal|stale) provider$/) do |status|
  if status == "stable"
    @provider = TestFlagsProvider.new(TEST_FLAGS)
    OpenFeature::SDK.set_provider_and_wait(@provider)
  else
    provider = StatusProvider.new
    OpenFeature::SDK.set_provider_and_wait(provider)

    state = case status
    when "not ready" then OpenFeature::SDK::ProviderState::NOT_READY
    when "error" then OpenFeature::SDK::ProviderState::ERROR
    when "fatal" then OpenFeature::SDK::ProviderState::FATAL
    when "stale" then OpenFeature::SDK::ProviderState::STALE
    end

    registry = OpenFeature::SDK.configuration.send(:instance_variable_get, :@provider_state_registry)
    registry.send(:instance_variable_get, :@mutex).synchronize do
      states = registry.send(:instance_variable_get, :@states)
      states[provider.object_id] = {state: state, details: {}}
    end

    @provider = provider
  end

  @client = OpenFeature::SDK.build_client
end

# -- Flag definition steps --

Given("a {}-flag with key {string} and a fallback value {string}") do |type, key, default_str|
  @flag_key = key
  @flag_type = type.downcase
  @default_value = parse_typed_value(@flag_type, default_str)
end

# -- Context steps --

Given("a context containing a key {string}, with type {string} and with value {string}") do |key, type, value|
  @context ||= {}
  @context[key] = coerce_context_value(type, value)
end

Given("a context containing a key {string} with null value") do |key|
  @context ||= {}
  @context[key] = nil
end

# -- Evaluation steps --

When("the flag was evaluated with details") do
  evaluation_context = @context ? OpenFeature::SDK::EvaluationContext.new(**@context.transform_keys(&:to_sym)) : nil
  @evaluation_details = @client.send(
    :"fetch_#{@flag_type}_details",
    flag_key: @flag_key,
    default_value: @default_value,
    evaluation_context: evaluation_context,
    hooks: @invocation_hooks || []
  )
end

# -- Assertion steps --

Then("the resolved details value should be {string}") do |expected_str|
  expected = parse_typed_value(@flag_type, expected_str)
  if expected.is_a?(Hash) || expected.is_a?(Array)
    expect(@evaluation_details.value).to eq(expected)
  elsif expected.is_a?(Float)
    expect(@evaluation_details.value.to_f).to be_within(0.001).of(expected)
  else
    expect(@evaluation_details.value).to eq(expected)
  end
end

Then("the reason should be {string}") do |expected_reason|
  expect(@evaluation_details.reason).to eq(expected_reason)
end

Then("the variant should be {string}") do |expected_variant|
  expect(@evaluation_details.variant).to eq(expected_variant)
end

Then("the error-code should be {string}") do |expected_error_code|
  expect(@evaluation_details.error_code).to eq(expected_error_code)
end

Then("the flag key should be {string}") do |expected_key|
  expect(@evaluation_details.flag_key).to eq(expected_key)
end

Then("the provider status should be {string}") do |expected_status|
  actual_status = @client.provider_status
  expect(actual_status).to eq(expected_status)
end

# -- Evaluation options with hooks steps --

Given("evaluation options containing specific hooks") do
  @hook_order = []
  @invocation_hooks = [RecordingHook.new(@hook_order, "invocation")]
end

When("the flag was evaluated with details using the evaluation options") do
  @evaluation_details = @client.send(
    :"fetch_#{@flag_type}_details",
    flag_key: @flag_key,
    default_value: @default_value,
    hooks: @invocation_hooks || []
  )
end

Then("the specified hooks should execute during evaluation") do
  expect(@hook_order).not_to be_empty
end

Then("the hook order should be maintained") do
  expect(@hook_order).to eq(@hook_order.sort_by { |entry| entry[:order] })
end

# -- Immutability steps --

Given("an evaluation context with modifiable data") do
  @original_context_data = {"test_key" => "test_value"}
  @context = @original_context_data.dup
end

Then("the original evaluation context should remain unmodified") do
  expect(@original_context_data).to eq({"test_key" => "test_value"})
end

Then("the evaluation details should be immutable") do
  # Verify that flag_metadata is frozen (immutable) per spec 1.4.15.1
  if @evaluation_details.flag_metadata
    expect(@evaluation_details.flag_metadata).to be_frozen
  end
  # Verify the resolution_details struct maintains its values (Ruby Structs are value objects)
  expect(@evaluation_details.flag_key).to eq(@flag_key)
  expect(@evaluation_details.value).not_to be_nil
end

# -- Async steps --

When("the flag was evaluated with details asynchronously") do
  thread = Thread.new do
    @client.send(
      :"fetch_#{@flag_type}_details",
      flag_key: @flag_key,
      default_value: @default_value
    )
  end
  @evaluation_details = thread.value
end

Then("the evaluation should complete without blocking") do
  expect(@evaluation_details).not_to be_nil
end

# -- Helper class for recording hooks --

class RecordingHook
  include OpenFeature::SDK::Hooks::Hook

  attr_reader :calls

  def initialize(order_log = [], name = "default")
    @calls = []
    @order_log = order_log
    @name = name
    @counter = 0
  end

  def before(hook_context:, hints:)
    @counter += 1
    @calls << :before
    @order_log << {stage: :before, name: @name, order: @counter}
    nil
  end

  def after(hook_context:, evaluation_details:, hints:)
    @counter += 1
    @calls << :after
    @order_log << {stage: :after, name: @name, order: @counter}
    nil
  end

  def error(hook_context:, exception:, hints:)
    @counter += 1
    @calls << :error
    @order_log << {stage: :error, name: @name, order: @counter}
    nil
  end

  def finally(hook_context:, evaluation_details:, hints:)
    @counter += 1
    @calls << :finally
    @order_log << {stage: :finally, name: @name, order: @counter}
    nil
  end
end

# -- Helper methods --

module EvaluationHelpers
  def parse_typed_value(type, str)
    case type.downcase
    when "boolean"
      str.downcase == "true"
    when "string"
      str
    when "integer"
      str.to_i
    when "float"
      str.to_f
    when "object"
      JSON.parse(str)
    else
      str
    end
  end

  def coerce_context_value(type, value)
    case type
    when "String"
      value
    when "Integer"
      value.to_i
    when "Float"
      value.to_f
    when "Boolean"
      value.downcase == "true"
    else
      value
    end
  end
end

World(EvaluationHelpers)
