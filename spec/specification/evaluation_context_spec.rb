# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Evaluation Context" do
  context "3.1 Fields" do
    let(:context_with_custom_fields) { OpenFeature::SDK::EvaluationContext.new("favorite_fruit" => "banana", "favorite_music" => "maryland beach ska rock") }

    context "Requirement 3.1.1" do
      specify "The evaluation context structure MUST define an optional targeting key field of type string, identifying the subject of the flag evaluation." do
        context_with_targeting = OpenFeature::SDK::EvaluationContext.new(targeting_key: "test target")
        context_without_targeting = OpenFeature::SDK::EvaluationContext.new

        expect(context_with_targeting.targeting_key).to eq("test target")
        expect(context_without_targeting.targeting_key).to be_nil
      end
    end

    context "Requirement 3.1.2" do
      specify "The evaluation context MUST support the inclusion of custom fields, having keys of type string, and values of type boolean | string | number | datetime | structure." do
        expect(context_with_custom_fields.fields).to eq({"favorite_fruit" => "banana", "favorite_music" => "maryland beach ska rock", "targeting_key" => nil})
      end
    end

    context "Requirement 3.1.3" do
      specify "The evaluation context MUST support fetching the custom fields by key" do
        expect(context_with_custom_fields.field("favorite_music")).to eq("maryland beach ska rock")
      end

      specify "and also fetching all key value pairs." do
        expect(context_with_custom_fields.fields).to eq({"favorite_fruit" => "banana", "favorite_music" => "maryland beach ska rock", "targeting_key" => nil})
      end
    end

    context "Requirement 3.1.4" do
      specify "The evaluation context fields MUST have an unique key." do
        context = OpenFeature::SDK::EvaluationContext.new("favorite_fruit" => "banana", "favorite_fruit" => "apple") # standard:disable Lint/DuplicateHashKey

        expect(context.fields).to eq({"favorite_fruit" => "apple", "targeting_key" => nil})
      end
    end
  end

  context "3.2 Context Levels and Merging" do
    context "Condition 3.2.1 - The implementation uses the dynamic-context paradigm." do
      context "Conditional Requirement 3.2.1.1" do
        let(:evaluation_context) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "testing") }

        specify "The API MUST have a method for supplying evaluation context." do
          OpenFeature::SDK.configure do |c|
            c.evaluation_context = evaluation_context
          end

          expect(OpenFeature::SDK.evaluation_context).to eq(evaluation_context)
        end

        specify "The Client MUST have a method for supplying evaluation context." do
          client = OpenFeature::SDK.build_client(evaluation_context: evaluation_context)

          expect(client.evaluation_context).to eq(evaluation_context)
        end

        specify "The invocation MUST have a method for supplying evaluation context." do
          client = OpenFeature::SDK.build_client

          expect { client.fetch_boolean_value(flag_key: "testing", default_value: true, evaluation_context:) }.not_to raise_error
        end
      end
    end
  end
end
