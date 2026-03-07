# frozen_string_literal: true

# Step definitions for the deprecated evaluation.feature.
# These use different step patterns from evaluation_v2.feature.

# -- Basic value evaluation --

When("a boolean flag with key {string} is evaluated with default value {string}") do |key, default_str|
  @flag_key = key
  @flag_type = "boolean"
  @default_value = (default_str.downcase == "true")
  @resolved_value = @client.fetch_boolean_value(flag_key: key, default_value: @default_value)
end

Then("the resolved boolean value should be {string}") do |expected_str|
  expected = (expected_str.downcase == "true")
  expect(@resolved_value).to eq(expected)
end

When("a string flag with key {string} is evaluated with default value {string}") do |key, default_str|
  @flag_key = key
  @flag_type = "string"
  @default_value = default_str
  @resolved_value = @client.fetch_string_value(flag_key: key, default_value: default_str)
end

Then("the resolved string value should be {string}") do |expected|
  expect(@resolved_value).to eq(expected)
end

When("an integer flag with key {string} is evaluated with default value {int}") do |key, default_val|
  @flag_key = key
  @flag_type = "integer"
  @default_value = default_val
  @resolved_value = @client.fetch_integer_value(flag_key: key, default_value: default_val)
end

Then("the resolved integer value should be {int}") do |expected|
  expect(@resolved_value).to eq(expected)
end

When("a float flag with key {string} is evaluated with default value {float}") do |key, default_val|
  @flag_key = key
  @flag_type = "float"
  @default_value = default_val
  @resolved_value = @client.fetch_float_value(flag_key: key, default_value: default_val)
end

Then("the resolved float value should be {float}") do |expected|
  expect(@resolved_value.to_f).to be_within(0.001).of(expected)
end

When("an object flag with key {string} is evaluated with a null default value") do |key|
  @flag_key = key
  @flag_type = "object"
  @default_value = {}
  @resolved_value = @client.fetch_object_value(flag_key: key, default_value: {})
end

Then("the resolved object value should be contain fields {string}, {string}, and {string}, with values {string}, {string} and {int}, respectively") do |f1, f2, f3, v1, v2, v3|
  expect(@resolved_value[f1]).to eq(v1 == "true")
  expect(@resolved_value[f2]).to eq(v2)
  expect(@resolved_value[f3]).to eq(v3)
end

# -- Detailed value evaluation --

When("a boolean flag with key {string} is evaluated with details and default value {string}") do |key, default_str|
  @flag_key = key
  @flag_type = "boolean"
  @default_value = (default_str.downcase == "true")
  @evaluation_details = @client.fetch_boolean_details(flag_key: key, default_value: @default_value)
end

Then("the resolved boolean details value should be {string}, the variant should be {string}, and the reason should be {string}") do |value_str, variant, reason|
  expected_value = (value_str.downcase == "true")
  expect(@evaluation_details.value).to eq(expected_value)
  expect(@evaluation_details.variant).to eq(variant)
  expect(@evaluation_details.reason).to eq(reason)
end

When("a string flag with key {string} is evaluated with details and default value {string}") do |key, default_str|
  @flag_key = key
  @flag_type = "string"
  @default_value = default_str
  @evaluation_details = @client.fetch_string_details(flag_key: key, default_value: default_str)
end

Then("the resolved string details value should be {string}, the variant should be {string}, and the reason should be {string}") do |value, variant, reason|
  expect(@evaluation_details.value).to eq(value)
  expect(@evaluation_details.variant).to eq(variant)
  expect(@evaluation_details.reason).to eq(reason)
end

When("an integer flag with key {string} is evaluated with details and default value {int}") do |key, default_val|
  @flag_key = key
  @flag_type = "integer"
  @default_value = default_val
  @evaluation_details = @client.fetch_integer_details(flag_key: key, default_value: default_val)
end

Then("the resolved integer details value should be {int}, the variant should be {string}, and the reason should be {string}") do |value, variant, reason|
  expect(@evaluation_details.value).to eq(value)
  expect(@evaluation_details.variant).to eq(variant)
  expect(@evaluation_details.reason).to eq(reason)
end

When("a float flag with key {string} is evaluated with details and default value {float}") do |key, default_val|
  @flag_key = key
  @flag_type = "float"
  @default_value = default_val
  @evaluation_details = @client.fetch_float_details(flag_key: key, default_value: default_val)
end

Then("the resolved float details value should be {float}, the variant should be {string}, and the reason should be {string}") do |value, variant, reason|
  expect(@evaluation_details.value.to_f).to be_within(0.001).of(value)
  expect(@evaluation_details.variant).to eq(variant)
  expect(@evaluation_details.reason).to eq(reason)
end

When("an object flag with key {string} is evaluated with details and a null default value") do |key|
  @flag_key = key
  @flag_type = "object"
  @default_value = {}
  @evaluation_details = @client.fetch_object_details(flag_key: key, default_value: {})
end

Then("the resolved object details value should be contain fields {string}, {string}, and {string}, with values {string}, {string} and {int}, respectively") do |f1, f2, f3, v1, v2, v3|
  expect(@evaluation_details.value[f1]).to eq(v1 == "true")
  expect(@evaluation_details.value[f2]).to eq(v2)
  expect(@evaluation_details.value[f3]).to eq(v3)
end

Then("the variant should be {string}, and the reason should be {string}") do |variant, reason|
  expect(@evaluation_details.variant).to eq(variant)
  expect(@evaluation_details.reason).to eq(reason)
end

# -- Context-aware evaluation --
# Note: evaluation.feature references a "context-aware" flag not in test-flags.json.
# We use "complex-targeted" which has similar INTERNAL/EXTERNAL behavior but different context keys.
# This scenario is kept for completeness but uses adapted context.

When("context contains keys {string}, {string}, {string}, {string} with values {string}, {string}, {int}, {string}") do |k1, k2, k3, k4, v1, v2, v3, v4|
  @context = {
    k1 => v1,
    k2 => v2,
    k3 => v3,
    k4 => (v4.downcase == "true")
  }
end

When("a flag with key {string} is evaluated with default value {string}") do |key, default_str|
  @flag_key = key
  @flag_type = "string"
  @default_value = default_str
  evaluation_context = @context ? OpenFeature::SDK::EvaluationContext.new(**@context.transform_keys(&:to_sym)) : nil
  @resolved_value = @client.fetch_string_value(
    flag_key: key,
    default_value: default_str,
    evaluation_context: evaluation_context
  )
end

Then("the resolved string response should be {string}") do |expected|
  expect(@resolved_value).to eq(expected)
end

Then("the resolved flag value is {string} when the context is empty") do |expected|
  result = @client.fetch_string_value(flag_key: @flag_key, default_value: @default_value)
  expect(result).to eq(expected)
end

# -- Error scenarios --

When("a non-existent string flag with key {string} is evaluated with details and a fallback value {string}") do |key, default_str|
  @flag_key = key
  @flag_type = "string"
  @default_value = default_str
  @evaluation_details = @client.fetch_string_details(flag_key: key, default_value: default_str)
end

Then("the default string value should be returned") do
  expect(@evaluation_details.value).to eq(@default_value)
end

Then("the reason should indicate an error and the error code should indicate a missing flag with {string}") do |error_code|
  expect(@evaluation_details.reason).to eq("ERROR")
  expect(@evaluation_details.error_code).to eq(error_code)
end

When("a string flag with key {string} is evaluated as an integer, with details and a fallback value {int}") do |key, default_val|
  @flag_key = key
  @flag_type = "integer"
  @default_value = default_val
  @evaluation_details = @client.fetch_integer_details(flag_key: key, default_value: default_val)
end

Then("the default integer value should be returned") do
  expect(@evaluation_details.value).to eq(@default_value)
end

Then("the reason should indicate an error and the error code should indicate a type mismatch with {string}") do |error_code|
  expect(@evaluation_details.reason).to eq("ERROR")
  expect(@evaluation_details.error_code).to eq(error_code)
end
