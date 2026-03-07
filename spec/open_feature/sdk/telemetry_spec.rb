# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Telemetry do
  let(:client_metadata) { OpenFeature::SDK::ClientMetadata.new(domain: "test-domain") }
  let(:provider_metadata) { OpenFeature::SDK::Provider::ProviderMetadata.new(name: "test-provider") }
  let(:evaluation_context) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-123") }

  let(:hook_context) do
    OpenFeature::SDK::Hooks::HookContext.new(
      flag_key: "my-flag",
      flag_value_type: :boolean,
      default_value: false,
      evaluation_context: evaluation_context,
      client_metadata: client_metadata,
      provider_metadata: provider_metadata
    )
  end

  let(:flag_metadata) do
    {
      "contextId" => "ctx-456",
      "flagSetId" => "set-789",
      "version" => "v1.0"
    }
  end

  let(:resolution_details) do
    OpenFeature::SDK::Provider::ResolutionDetails.new(
      value: true,
      reason: "TARGETING_MATCH",
      variant: "enabled",
      flag_metadata: flag_metadata
    )
  end

  let(:evaluation_details) do
    OpenFeature::SDK::EvaluationDetails.new(
      flag_key: "my-flag",
      resolution_details: resolution_details
    )
  end

  def build_details(flag_key: "my-flag", **resolution_attrs)
    resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(**resolution_attrs)
    OpenFeature::SDK::EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution)
  end

  describe ".create_evaluation_event" do
    context "with full data" do
      it "returns an EvaluationEvent with all attributes populated" do
        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: evaluation_details
        )

        expect(event).to be_a(OpenFeature::SDK::Telemetry::EvaluationEvent)
        expect(event.name).to eq("feature_flag.evaluation")
        expect(event.attributes).to eq(
          "feature_flag.key" => "my-flag",
          "feature_flag.provider.name" => "test-provider",
          "feature_flag.result.variant" => "enabled",
          "feature_flag.result.reason" => "targeting_match",
          "feature_flag.context.id" => "ctx-456",
          "feature_flag.set.id" => "set-789",
          "feature_flag.version" => "v1.0"
        )
      end
    end

    context "variant vs value precedence" do
      it "uses variant when present and omits value" do
        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: evaluation_details
        )

        expect(event.attributes).to have_key("feature_flag.result.variant")
        expect(event.attributes).not_to have_key("feature_flag.result.value")
      end

      it "uses value when variant is nil" do
        details = build_details(flag_key: "color-flag", value: "blue", reason: "STATIC")

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes["feature_flag.result.value"]).to eq("blue")
        expect(event.attributes).not_to have_key("feature_flag.result.variant")
      end
    end

    context "enum downcasing" do
      it "downcases reason to OTel convention" do
        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: evaluation_details
        )

        expect(event.attributes["feature_flag.result.reason"]).to eq("targeting_match")
      end

      it "downcases error_code to OTel convention" do
        details = build_details(
          flag_key: "missing-flag", value: false, reason: "ERROR",
          error_code: "FLAG_NOT_FOUND", error_message: "Flag not found"
        )

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes["error.type"]).to eq("flag_not_found")
        expect(event.attributes["feature_flag.result.reason"]).to eq("error")
      end
    end

    context "error attributes" do
      it "includes error attributes only when error occurred" do
        details = build_details(
          flag_key: "bad-flag", value: false, reason: "ERROR",
          error_code: "PARSE_ERROR", error_message: "Could not parse flag"
        )

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes["error.type"]).to eq("parse_error")
        expect(event.attributes["error.message"]).to eq("Could not parse flag")
      end

      it "omits error attributes when no error" do
        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: evaluation_details
        )

        expect(event.attributes).not_to have_key("error.type")
        expect(event.attributes).not_to have_key("error.message")
      end
    end

    context "nil evaluation_details" do
      it "returns event with only flag_key and available context" do
        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: nil
        )

        expect(event.name).to eq("feature_flag.evaluation")
        expect(event.attributes).to eq(
          "feature_flag.key" => "my-flag",
          "feature_flag.provider.name" => "test-provider",
          "feature_flag.context.id" => "user-123"
        )
      end
    end

    context "flag metadata" do
      it "ignores nil flag_metadata" do
        details = build_details(value: true, variant: "on")

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes).not_to have_key("feature_flag.set.id")
        expect(event.attributes).not_to have_key("feature_flag.version")
      end

      it "ignores empty flag_metadata" do
        details = build_details(value: true, variant: "on", flag_metadata: {})

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes).not_to have_key("feature_flag.set.id")
        expect(event.attributes).not_to have_key("feature_flag.version")
      end

      it "ignores unknown metadata keys" do
        details = build_details(
          value: true, variant: "on",
          flag_metadata: {"customKey" => "custom-value", "anotherKey" => 42}
        )

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes).not_to have_key("customKey")
        expect(event.attributes).not_to have_key("anotherKey")
      end
    end

    context "context ID precedence" do
      it "uses metadata contextId over targeting_key" do
        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: evaluation_details
        )

        # flag_metadata has contextId "ctx-456", targeting_key is "user-123"
        expect(event.attributes["feature_flag.context.id"]).to eq("ctx-456")
      end

      it "falls back to targeting_key when no contextId in metadata" do
        details = build_details(value: true, variant: "on", flag_metadata: {"flagSetId" => "set-1"})

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes["feature_flag.context.id"]).to eq("user-123")
      end

      it "omits context ID when neither targeting_key nor contextId available" do
        bare_context = OpenFeature::SDK::EvaluationContext.new(env: "prod")
        bare_hook_context = OpenFeature::SDK::Hooks::HookContext.new(
          flag_key: "my-flag",
          flag_value_type: :boolean,
          default_value: false,
          evaluation_context: bare_context
        )
        details = build_details(value: true, variant: "on")

        event = described_class.create_evaluation_event(
          hook_context: bare_hook_context,
          evaluation_details: details
        )

        expect(event.attributes).not_to have_key("feature_flag.context.id")
      end
    end
  end
end
