# frozen_string_literal: true

require_relative "../../../spec_helper"

require "openfeature/sdk/evaluation/context"
require "date"

# https://openfeature.dev/specification/sections/evaluation-context
RSpec.describe OpenFeature::SDK::Evaluation::Context do
  subject(:evaluation_context) { described_class.new({ targeting_key: "targeting_key", custom_field: "abc" }) }
  context "3.1 Fields" do
    context "Requirement 3.1.1" do
      it "MUST define an optional targeting key field of type string, identifying the subject of the flag evaluation." do
        expect(evaluation_context).to respond_to(:targeting_key)
        expect(evaluation_context).to respond_to(:targeting_key=)
        expect(evaluation_context.targeting_key).to be_a(String)
      end
    end

    context "Requirement 3.1.2" do
      context "MUST support the inclusion of custom fields, having keys of type string, and values of type boolean | string | number | datetime | structure." do
        context "boolean" do
          it do
            expect(evaluation_context[:boolean_key] = true).to eq(true)
            expect(evaluation_context[:boolean_key]).to be_a(TrueClass)
          end
        end
        context "string" do
          it do
            expect(evaluation_context[:string_key] = "string_value").to eq("string_value")
            expect(evaluation_context[:string_key]).to be_a(String)
          end
        end
        context "number" do
          it do
            expect(evaluation_context[:number_key] = 1).to eq(1)
            expect(evaluation_context[:number_key]).to be_a(Integer)
          end
        end
        context "datetime" do
          it do
            expect(evaluation_context[:datetime_key] = DateTime.now).to be_a(DateTime)
            expect(evaluation_context[:datetime_key]).to be_a(DateTime)
          end
        end
        context "structure" do
          it do
            expect(evaluation_context[:structure_key] = { key: "value" }).to eq({ key: "value" })
            expect(evaluation_context[:structure_key]).to be_a(Hash)
          end
        end
      end
    end

    context "Requirement 3.1.3" do
      it "MUST support fetching the custom fields by key and also fetching all key value pairs." do
        expect(evaluation_context).to respond_to(:to_h)
        expect(evaluation_context.to_h).to eq({ targeting_key: "targeting_key", custom_field: "abc" })
      end
    end

    context "Requirement 3.1.4" do
      it "MUST have an unique key." do
        evaluation_context[:key] = "value"
        expect(evaluation_context[:key]).to eq("value")
        evaluation_context[:key] = "new_value"
        expect(evaluation_context[:key]).to eq("new_value")
        expect(evaluation_context.keys).to eq(evaluation_context.keys.uniq)
      end
    end

    context "Requirement 3.2.2" do
      let(:provider) { instance_spy("NoOpProvider") }

      it "MUST be merged in the order: API (global; lowest precedence) -> client -> invocation -> before hooks (highest precedence), with duplicate values being overwritten" do
        api_context = described_class.new({ a: "api_value", b: "api_value" })
        client_context = described_class.new({ c: "client_value", b: "client_value" })
        invocation_context = described_class.new({ d: "invocation_value", b: "invocation_value" })

        OpenFeature::SDK.configure do |config|
          config.context = api_context
        end
        expected_context = { a: "api_value", c: "client_value", d: "invocation_value", b: "invocation_value" }

        client = OpenFeature::SDK::Client.new(provider: provider, context: client_context)
        client.fetch_boolean_value(flag_key: "flag_key", default_value: false, evaluation_context: invocation_context)
        expect(provider).to have_received(:fetch_boolean_value).with(flag_key: "flag_key", default_value: false, evaluation_context: expected_context)
      end
    end
  end
end
