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
        expect(context_with_custom_fields.fields).to eq({"favorite_fruit" => "banana", "favorite_music" => "maryland beach ska rock"})
      end
    end

    context "Requirement 3.1.3" do
      specify "The evaluation context MUST support fetching the custom fields by key" do
        expect(context_with_custom_fields.field("favorite_music")).to eq("maryland beach ska rock")
      end

      specify "and also fetching all key value pairs." do
        expect(context_with_custom_fields.fields).to eq({"favorite_fruit" => "banana", "favorite_music" => "maryland beach ska rock"})
      end
    end

    context "Requirement 3.1.4" do
      specify "The evaluation context fields MUST have an unique key." do
        context = OpenFeature::SDK::EvaluationContext.new("favorite_fruit" => "banana", "favorite_fruit" => "apple") # standard:disable Lint/DuplicateHashKey

        expect(context.fields).to eq({"favorite_fruit" => "apple"})
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

    specify "Requirement 3.2.3 - Evaluation context MUST be merged in the order: API (global; lowest precedence) -> transaction -> client -> invocation -> before hooks (highest precedence), with duplicate values being overwritten." do
      api_context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "api")
      transaction_context = OpenFeature::SDK::EvaluationContext.new("targeting_key" => "transaction", "transaction-related" => "field")
      client_context = OpenFeature::SDK::EvaluationContext.new("targeting_key" => "client", "client-related" => "field")
      invocation_context = OpenFeature::SDK::EvaluationContext.new("targeting_key" => "invocation", "invocation-related" => "field")

      propagator = OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new
      OpenFeature::SDK.configure do |c|
        c.evaluation_context = api_context
        c.transaction_context_propagator = propagator
      end
      propagator.set_transaction_context(transaction_context)

      client = OpenFeature::SDK.build_client(evaluation_context: client_context)

      expect_any_instance_of(OpenFeature::SDK::EvaluationContextBuilder).to receive(:call).with(
        api_context: api_context,
        transaction_context: transaction_context,
        client_context: client_context,
        invocation_context: invocation_context
      ).and_call_original

      client.fetch_boolean_value(flag_key: "testing", default_value: true, evaluation_context: invocation_context)

      propagator.set_transaction_context(nil)
    end
  end

  context "3.3 Transaction Context Propagation" do
    after do
      OpenFeature::SDK.configure { |c| c.transaction_context_propagator = nil }
    end

    context "Requirement 3.3.1.1" do
      specify "The API SHOULD have a method for setting a transaction context propagator." do
        propagator = OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new
        OpenFeature::SDK.set_transaction_context_propagator(propagator)

        expect(OpenFeature::SDK.configuration.transaction_context_propagator).to eq(propagator)
      end
    end

    context "Condition 3.3.1.2 - A transaction context propagator is configured." do
      let(:propagator) { OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new }

      before do
        OpenFeature::SDK.set_transaction_context_propagator(propagator)
      end

      context "Conditional Requirement 3.3.1.2.1" do
        specify "The API MUST have a method for setting the evaluation context of the transaction context propagator for the current transaction." do
          context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "txn-user")
          OpenFeature::SDK.set_transaction_context(context)

          expect(propagator.get_transaction_context).to eq(context)

          propagator.set_transaction_context(nil)
        end
      end
    end

    context "Requirement 3.3.1.2.2" do
      specify "A transaction context propagator MUST have a method for setting the evaluation context of the current transaction." do
        propagator = OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new
        context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "txn-user")

        propagator.set_transaction_context(context)

        expect(propagator.get_transaction_context).to eq(context)

        propagator.set_transaction_context(nil)
      end
    end

    context "Requirement 3.3.1.2.3" do
      specify "A transaction context propagator MUST have a method for getting the evaluation context of the current transaction." do
        propagator = OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new

        expect(propagator.get_transaction_context).to be_nil

        context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "txn-user")
        propagator.set_transaction_context(context)

        expect(propagator.get_transaction_context).to eq(context)

        propagator.set_transaction_context(nil)
      end
    end
  end
end
