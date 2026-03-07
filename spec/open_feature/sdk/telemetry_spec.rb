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
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: "blue",
          reason: "STATIC"
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "color-flag",
          resolution_details: resolution
        )

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
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: false,
          reason: "ERROR",
          error_code: "FLAG_NOT_FOUND",
          error_message: "Flag not found"
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "missing-flag",
          resolution_details: resolution
        )

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes["error.type"]).to eq("flag_not_found")
        expect(event.attributes["feature_flag.result.reason"]).to eq("error")
      end
    end
  end
end
