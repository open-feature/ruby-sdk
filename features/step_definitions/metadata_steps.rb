# frozen_string_literal: true

Then("the resolved metadata should contain") do |table|
  metadata = @evaluation_details.flag_metadata
  expect(metadata).not_to be_nil

  table.hashes.each do |row|
    key = row["key"]
    expected_type = row["metadata_type"]
    expected_value = row["value"]

    actual = metadata[key]

    case expected_type
    when "String"
      expect(actual).to eq(expected_value)
    when "Integer"
      expect(actual).to eq(expected_value.to_i)
    when "Float"
      expect(actual.to_f).to be_within(0.001).of(expected_value.to_f)
    when "Boolean"
      expect(actual).to eq(expected_value.downcase == "true")
    end
  end
end

Then("the resolved metadata is empty") do
  metadata = @evaluation_details.flag_metadata
  expect(metadata).to be_nil.or eq({})
end
