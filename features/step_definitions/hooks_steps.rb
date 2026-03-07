# frozen_string_literal: true

# Hook that records lifecycle calls and captures evaluation details
class DetailCapturingHook
  include OpenFeature::SDK::Hooks::Hook

  attr_reader :stages_called, :after_details, :finally_details, :error_called

  def initialize
    @stages_called = []
    @after_details = nil
    @finally_details = nil
    @error_called = false
  end

  def before(hook_context:, hints:)
    @stages_called << "before"
    nil
  end

  def after(hook_context:, evaluation_details:, hints:)
    @stages_called << "after"
    @after_details = evaluation_details
    nil
  end

  def error(hook_context:, exception:, hints:)
    @stages_called << "error"
    @error_called = true
    nil
  end

  def finally(hook_context:, evaluation_details:, hints:)
    @stages_called << "finally"
    @finally_details = evaluation_details
    nil
  end
end

Given("a client with added hook") do
  @detail_hook = DetailCapturingHook.new
  @client.hooks = [@detail_hook]
end

Then("the {string} hook should have been executed") do |stage|
  expect(@detail_hook.stages_called).to include(stage)
end

Then("the {string} hooks should be called with evaluation details") do |stages_str, table|
  stages = stages_str.split(", ").map(&:strip)
  expected = {}
  table.hashes.each do |row|
    expected[row["key"]] = {data_type: row["data_type"], value: row["value"]}
  end

  stages.each do |stage|
    details = case stage
    when "after"
      @detail_hook.after_details
    when "finally"
      @detail_hook.finally_details
    end

    expect(details).not_to be_nil, "Expected #{stage} hook to have evaluation details"

    expected.each do |key, spec|
      actual_value = details.send(key.to_sym)
      expected_value = spec[:value]

      if expected_value == "null"
        expect(actual_value).to be_nil, "Expected #{key} to be nil in #{stage} hook details, got #{actual_value.inspect}"
      else
        case spec[:data_type]
        when "boolean"
          expect(actual_value).to eq(expected_value == "true"), "Expected #{key}=#{expected_value} in #{stage}, got #{actual_value}"
        when "string"
          expect(actual_value.to_s).to eq(expected_value), "Expected #{key}=#{expected_value} in #{stage}, got #{actual_value}"
        when "integer"
          expect(actual_value).to eq(expected_value.to_i), "Expected #{key}=#{expected_value} in #{stage}, got #{actual_value}"
        when "float"
          expect(actual_value.to_f).to be_within(0.001).of(expected_value.to_f)
        end
      end
    end
  end
end
