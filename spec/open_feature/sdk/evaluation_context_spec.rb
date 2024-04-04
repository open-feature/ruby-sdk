require "spec_helper"

RSpec.describe OpenFeature::SDK::EvaluationContext do
  let(:evaluation_context) { described_class.new("targeting_key" => "base", "favorite_fruit" => "apple") }

  describe "#merge" do
    context "when key exists in overriding context" do
      it "overrides" do
        overriding_context = described_class.new("targeting_key" => "new", "favorite_fruit" => "banana", "favorite_day" => "Monday")

        new_context = evaluation_context.merge(overriding_context)

        expect(new_context).to eq(described_class.new("targeting_key" => "new", "favorite_fruit" => "banana", "favorite_day" => "Monday"))
      end
    end

    context "when new keys exist in overwriting context" do
      it "merges" do
        overriding_context = described_class.new("favorite_day" => "Monday")

        new_context = evaluation_context.merge(overriding_context)

        expect(new_context).to eq(described_class.new("targeting_key" => "base", "favorite_fruit" => "apple", "favorite_day" => "Monday"))
      end
    end
  end
end
