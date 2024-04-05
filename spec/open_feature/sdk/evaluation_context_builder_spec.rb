require "spec_helper"

RSpec.describe OpenFeature::SDK::EvaluationContextBuilder do
  let(:builder) { described_class.new }
  let(:api_context) { OpenFeature::SDK::EvaluationContext.new("targeting_key" => "api", "api" => "key") }
  let(:client_context) { OpenFeature::SDK::EvaluationContext.new("targeting_key" => "client", "client" => "key") }
  let(:invocation_context) { OpenFeature::SDK::EvaluationContext.new("targeting_key" => "invocation", "invocation" => "key") }

  describe "#call" do
    context "when no available contexts" do
      it "returns nil" do
        result = builder.call(api_context: nil, client_context: nil, invocation_context: nil)

        expect(result).to be_nil
      end
    end

    context "when only api context" do
      it "returns api context" do
        result = builder.call(api_context:, client_context: nil, invocation_context: nil)

        expect(result).to eq(OpenFeature::SDK::EvaluationContext.new("targeting_key" => "api", "api" => "key"))
      end
    end

    context "when only client context" do
      it "returns client context" do
        result = builder.call(api_context: nil, client_context:, invocation_context: nil)

        expect(result).to eq(OpenFeature::SDK::EvaluationContext.new("targeting_key" => "client", "client" => "key"))
      end
    end

    context "when only invocation context" do
      it "returns invocation context" do
        result = builder.call(api_context: nil, client_context: nil, invocation_context:)

        expect(result).to eq(OpenFeature::SDK::EvaluationContext.new("targeting_key" => "invocation", "invocation" => "key"))
      end
    end

    context "when api and client contexts" do
      it "returns merged context" do
        result = builder.call(api_context:, client_context:, invocation_context: nil)

        expect(result).to eq(OpenFeature::SDK::EvaluationContext.new("targeting_key" => "client", "api" => "key", "client" => "key"))
      end
    end

    context "when client and invocation contexts" do
      it "returns merged context" do
        result = builder.call(api_context: nil, client_context:, invocation_context:)

        expect(result).to eq(OpenFeature::SDK::EvaluationContext.new("targeting_key" => "invocation", "client" => "key", "invocation" => "key"))
      end
    end

    context "when global and invocation contexts" do
      it "returns merged context" do
        result = builder.call(api_context:, client_context: nil, invocation_context:)

        expect(result).to eq(OpenFeature::SDK::EvaluationContext.new("targeting_key" => "invocation", "api" => "key", "invocation" => "key"))
      end
    end

    context "when all contexts" do
      it "returns merged context" do
        result = builder.call(api_context:, client_context:, invocation_context:)

        expect(result).to eq(OpenFeature::SDK::EvaluationContext.new("targeting_key" => "invocation", "api" => "key", "client" => "key", "invocation" => "key"))
      end
    end
  end
end
