# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Hooks::LoggingHook do
  let(:client_metadata) { OpenFeature::SDK::ClientMetadata.new(domain: "test-domain") }
  let(:provider_metadata) { OpenFeature::SDK::Provider::ProviderMetadata.new(name: "test-provider") }
  let(:evaluation_context) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-123", env: "prod") }

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

  let(:evaluation_details) do
    resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
      value: true,
      reason: "TARGETING_MATCH",
      variant: "enabled"
    )
    OpenFeature::SDK::EvaluationDetails.new(
      flag_key: "my-flag",
      resolution_details: resolution
    )
  end

  let(:logger) { double("logger") }
  let(:hints) { OpenFeature::SDK::Hooks::Hints.new }

  describe "#before" do
    it "logs at debug level with correct fields" do
      hook = described_class.new(logger: logger)
      expect(logger).to receive(:debug) do |&block|
        message = block.call
        expect(message).to include("stage=before")
        expect(message).to include("domain=test-domain")
        expect(message).to include("provider_name=test-provider")
        expect(message).to include("flag_key=my-flag")
        expect(message).to include("default_value=false")
      end

      hook.before(hook_context: hook_context, hints: hints)
    end

    it "does not include evaluation_context by default" do
      hook = described_class.new(logger: logger)
      expect(logger).to receive(:debug) do |&block|
        message = block.call
        expect(message).not_to include("evaluation_context=")
      end

      hook.before(hook_context: hook_context, hints: hints)
    end

    it "includes evaluation_context when enabled" do
      hook = described_class.new(logger: logger, include_evaluation_context: true)
      expect(logger).to receive(:debug) do |&block|
        message = block.call
        expect(message).to include("evaluation_context=")
        expect(message).to include("targeting_key=user-123")
        expect(message).to include("env=prod")
      end

      hook.before(hook_context: hook_context, hints: hints)
    end

    it "returns nil" do
      hook = described_class.new(logger: logger)
      allow(logger).to receive(:debug)
      expect(hook.before(hook_context: hook_context, hints: hints)).to be_nil
    end
  end

  describe "#after" do
    it "logs at debug level with evaluation details" do
      hook = described_class.new(logger: logger)
      expect(logger).to receive(:debug) do |&block|
        message = block.call
        expect(message).to include("stage=after")
        expect(message).to include("domain=test-domain")
        expect(message).to include("provider_name=test-provider")
        expect(message).to include("flag_key=my-flag")
        expect(message).to include("default_value=false")
        expect(message).to include("reason=TARGETING_MATCH")
        expect(message).to include("variant=enabled")
        expect(message).to include("value=true")
      end

      hook.after(hook_context: hook_context, evaluation_details: evaluation_details, hints: hints)
    end

    it "omits reason and variant when nil" do
      resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: "hello")
      details = OpenFeature::SDK::EvaluationDetails.new(flag_key: "my-flag", resolution_details: resolution)
      hook = described_class.new(logger: logger)

      expect(logger).to receive(:debug) do |&block|
        message = block.call
        expect(message).not_to include("reason=")
        expect(message).not_to include("variant=")
        expect(message).to include("value=hello")
      end

      hook.after(hook_context: hook_context, evaluation_details: details, hints: hints)
    end

    it "includes evaluation_context when enabled" do
      hook = described_class.new(logger: logger, include_evaluation_context: true)
      expect(logger).to receive(:debug) do |&block|
        message = block.call
        expect(message).to include("evaluation_context=")
        expect(message).to include("targeting_key=user-123")
      end

      hook.after(hook_context: hook_context, evaluation_details: evaluation_details, hints: hints)
    end

    it "returns nil" do
      hook = described_class.new(logger: logger)
      allow(logger).to receive(:debug)
      expect(hook.after(hook_context: hook_context, evaluation_details: evaluation_details, hints: hints)).to be_nil
    end
  end

  describe "#error" do
    let(:exception) { StandardError.new("something went wrong") }

    it "logs at error level with error fields" do
      hook = described_class.new(logger: logger)
      expect(logger).to receive(:error) do |&block|
        message = block.call
        expect(message).to include("stage=error")
        expect(message).to include("domain=test-domain")
        expect(message).to include("provider_name=test-provider")
        expect(message).to include("flag_key=my-flag")
        expect(message).to include("default_value=false")
        expect(message).to include("error_code=GENERAL")
        expect(message).to include("error_message=something went wrong")
      end

      hook.error(hook_context: hook_context, exception: exception, hints: hints)
    end

    it "uses error_code from exception when available" do
      error_with_code = OpenFeature::SDK::ProviderInitializationError.new("init failed")
      hook = described_class.new(logger: logger)

      expect(logger).to receive(:error) do |&block|
        message = block.call
        expect(message).to include("error_code=PROVIDER_FATAL")
      end

      hook.error(hook_context: hook_context, exception: error_with_code, hints: hints)
    end

    it "includes evaluation_context when enabled" do
      hook = described_class.new(logger: logger, include_evaluation_context: true)
      expect(logger).to receive(:error) do |&block|
        message = block.call
        expect(message).to include("evaluation_context=")
        expect(message).to include("targeting_key=user-123")
      end

      hook.error(hook_context: hook_context, exception: exception, hints: hints)
    end

    it "returns nil" do
      hook = described_class.new(logger: logger)
      allow(logger).to receive(:error)
      expect(hook.error(hook_context: hook_context, exception: exception, hints: hints)).to be_nil
    end
  end

  describe "#finally" do
    it "does not log (uses default no-op from Hook module)" do
      hook = described_class.new(logger: logger)
      expect(logger).not_to receive(:debug)
      expect(logger).not_to receive(:info)
      expect(logger).not_to receive(:error)

      hook.finally(hook_context: hook_context, evaluation_details: evaluation_details, hints: hints)
    end
  end

  describe "logger fallback" do
    it "falls back to OpenFeature::SDK.configuration.logger" do
      config_logger = double("config_logger")
      allow(OpenFeature::SDK).to receive(:configuration).and_return(
        instance_double(OpenFeature::SDK::Configuration, logger: config_logger)
      )

      hook = described_class.new
      expect(config_logger).to receive(:debug)

      hook.before(hook_context: hook_context, hints: hints)
    end

    it "handles nil logger gracefully" do
      allow(OpenFeature::SDK).to receive(:configuration).and_return(
        instance_double(OpenFeature::SDK::Configuration, logger: nil)
      )

      hook = described_class.new
      expect { hook.before(hook_context: hook_context, hints: hints) }.not_to raise_error
    end
  end
end
