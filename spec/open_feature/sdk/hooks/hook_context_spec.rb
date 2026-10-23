# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Hooks::HookContext do
  let(:evaluation_context) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-123") }
  let(:client_metadata) { OpenFeature::SDK::ClientMetadata.new(domain: "test-domain") }
  let(:provider_metadata) { OpenFeature::SDK::Provider::ProviderMetadata.new(name: "test-provider") }

  subject(:hook_context) do
    described_class.new(
      flag_key: "my-flag",
      flag_value_type: :boolean,
      default_value: false,
      evaluation_context: evaluation_context,
      client_metadata: client_metadata,
      provider_metadata: provider_metadata
    )
  end

  describe "immutable fields" do
    it "has a frozen flag_key" do
      expect(hook_context.flag_key).to eq("my-flag")
      expect(hook_context.flag_key).to be_frozen
    end

    it "has a frozen flag_value_type" do
      expect(hook_context.flag_value_type).to eq(:boolean)
      expect(hook_context.flag_value_type).to be_frozen
    end

    it "has a frozen default_value" do
      ctx = described_class.new(
        flag_key: "flag",
        flag_value_type: :object,
        default_value: {key: "value"},
        evaluation_context: nil
      )
      expect(ctx.default_value).to be_frozen
    end

    it "copies the default_value on first read, even once frozen" do
      ctx = described_class.new(flag_key: "flag", flag_value_type: :object, default_value: {"list" => []}, evaluation_context: nil).freeze
      expect(ctx.default_value["list"]).to be_frozen
    end

    it "exposes the default_value" do
      expect(hook_context.default_value).to eq(false)
    end

    it "does not allow setting flag_key" do
      expect { hook_context.flag_key = "other" }.to raise_error(NoMethodError)
    end

    it "does not allow setting flag_value_type" do
      expect { hook_context.flag_value_type = :string }.to raise_error(NoMethodError)
    end
  end

  describe "optional fields" do
    it "exposes client_metadata" do
      expect(hook_context.client_metadata.domain).to eq("test-domain")
    end

    it "exposes provider_metadata" do
      expect(hook_context.provider_metadata.name).to eq("test-provider")
    end

    it "allows nil client_metadata" do
      ctx = described_class.new(
        flag_key: "flag",
        flag_value_type: :string,
        default_value: "",
        evaluation_context: nil
      )
      expect(ctx.client_metadata).to be_nil
    end

    it "allows nil provider_metadata" do
      ctx = described_class.new(
        flag_key: "flag",
        flag_value_type: :string,
        default_value: "",
        evaluation_context: nil
      )
      expect(ctx.provider_metadata).to be_nil
    end
  end

  describe "evaluation_context" do
    it "allows setting evaluation_context" do
      new_context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-456")
      hook_context.evaluation_context = new_context
      expect(hook_context.evaluation_context.targeting_key).to eq("user-456")
    end

    it "keeps the evaluation context's class once frozen" do
      subclass = Class.new(OpenFeature::SDK::EvaluationContext) { def tenant = field("tenant") }
      ctx = described_class.new(flag_key: "flag", flag_value_type: :boolean, default_value: false,
        evaluation_context: subclass.new(tenant: "acme")).freeze

      expect(ctx.evaluation_context.tenant).to eq("acme")
    end

    it "is a frozen copy once the hook context is frozen" do
      hook_context.freeze

      expect(hook_context.evaluation_context).to eq(evaluation_context)
      expect(hook_context.evaluation_context.fields).to be_frozen
      expect(evaluation_context).not_to be_frozen
      expect { hook_context.evaluation_context = evaluation_context }.to raise_error(FrozenError)
    end
  end

  describe "values that can't be copied" do
    [Mutex.new, Thread::Queue.new, -> {}].each do |uncopyable|
      it "freezes a shallow copy when it holds a #{uncopyable.class}" do
        default = {held: uncopyable}
        ctx = described_class.new(flag_key: "flag", flag_value_type: :object, default_value: default, evaluation_context: nil)

        expect(ctx.default_value).to eq(default)
        expect(ctx.default_value).to be_frozen
        expect(default).not_to be_frozen
      end
    end
  end
end
