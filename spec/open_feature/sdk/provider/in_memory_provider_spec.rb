# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Provider::InMemoryProvider do
  subject(:provider) do
    described_class.new(
      {
        "bool" => true,
        "str" => "testing",
        "int" => 1,
        "float" => 1.0,
        "struct" => {"more" => "config"}
      }
    )
  end

  describe "#add_flag" do
    context "when flag doesn't exist" do
      it "adds flag" do
        provider.add_flag(flag_key: "new_flag", value: "new_value")

        fetched = provider.fetch_string_value(flag_key: "new_flag", default_value: "fallback")

        expect(fetched.value).to eq("new_value")
      end
    end

    context "when flag exists" do
      it "updates flag" do
        provider.add_flag(flag_key: "bool", value: false)

        fetched = provider.fetch_boolean_value(flag_key: "bool", default_value: true)

        expect(fetched.value).to eq(false)
      end
    end

    context "when attached to configuration" do
      it "emits PROVIDER_CONFIGURATION_CHANGED event" do
        config = instance_double("OpenFeature::SDK::Configuration")
        allow(config).to receive(:dispatch_provider_event)
        provider.send(:attach, config)

        provider.add_flag(flag_key: "new_flag", value: "new_value")

        expect(config).to have_received(:dispatch_provider_event).with(
          provider,
          OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED,
          flags_changed: ["new_flag"]
        )
      end
    end

    context "when not attached to configuration" do
      it "does not emit events" do
        expect { provider.add_flag(flag_key: "new_flag", value: "new_value") }.not_to raise_error
      end
    end
  end

  describe "#update_flags" do
    it "replaces all flags" do
      provider.update_flags({"new_key" => "new_value"})

      fetched = provider.fetch_string_value(flag_key: "new_key", default_value: "fallback")
      expect(fetched.value).to eq("new_value")

      old_fetched = provider.fetch_string_value(flag_key: "str", default_value: "fallback")
      expect(old_fetched.value).to eq("fallback")
      expect(old_fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
    end

    context "when attached to configuration" do
      it "emits PROVIDER_CONFIGURATION_CHANGED event with union of old and new flag keys" do
        config = instance_double("OpenFeature::SDK::Configuration")
        allow(config).to receive(:dispatch_provider_event)
        provider.send(:attach, config)

        provider.update_flags({"flag_a" => true, "flag_b" => false})

        expect(config).to have_received(:dispatch_provider_event).with(
          provider,
          OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED,
          flags_changed: contain_exactly("bool", "str", "int", "float", "struct", "flag_a", "flag_b")
        )
      end
    end

    context "when not attached to configuration" do
      it "does not emit events" do
        expect { provider.update_flags({"flag_a" => true}) }.not_to raise_error
      end
    end
  end

  describe "context callbacks (callable flag values)" do
    it "calls a Proc flag value with evaluation_context" do
      context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-123")
      flag_proc = proc { |ctx| ctx.targeting_key == "user-123" }
      provider = described_class.new({"dynamic_flag" => flag_proc})

      fetched = provider.fetch_boolean_value(flag_key: "dynamic_flag", default_value: false, evaluation_context: context)

      expect(fetched.value).to eq(true)
      expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::TARGETING_MATCH)
    end

    it "calls a lambda flag value with evaluation_context" do
      context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-456")
      flag_lambda = ->(ctx) { "hello-#{ctx.targeting_key}" }
      provider = described_class.new({"greeting" => flag_lambda})

      fetched = provider.fetch_string_value(flag_key: "greeting", default_value: "default", evaluation_context: context)

      expect(fetched.value).to eq("hello-user-456")
      expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::TARGETING_MATCH)
    end

    it "returns STATIC reason for non-callable values" do
      fetched = provider.fetch_string_value(flag_key: "str", default_value: "fallback")

      expect(fetched.value).to eq("testing")
      expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
    end
  end

  describe "#fetch_boolean_value" do
    context "when flag is found" do
      it "returns value as static" do
        fetched = provider.fetch_boolean_value(flag_key: "bool", default_value: false)

        expect(fetched.value).to eq(true)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
      end
    end

    context "when flag is not found" do
      it "returns default as flag not found" do
        fetched = provider.fetch_boolean_value(flag_key: "not here", default_value: false)

        expect(fetched.value).to eq(false)
        expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end
    end
  end

  describe "#fetch_string_value" do
    context "when flag is found" do
      it "returns value as static" do
        fetched = provider.fetch_string_value(flag_key: "str", default_value: "fallback")

        expect(fetched.value).to eq("testing")
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
      end
    end

    context "when flag is not found" do
      it "returns default as flag not found" do
        fetched = provider.fetch_string_value(flag_key: "not here", default_value: "fallback")

        expect(fetched.value).to eq("fallback")
        expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end
    end
  end

  describe "#fetch_number_value" do
    context "when flag is found" do
      it "returns int as static" do
        fetched = provider.fetch_number_value(flag_key: "int", default_value: 0)

        expect(fetched.value).to eq(1)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
      end
      it "returns float as static" do
        fetched = provider.fetch_number_value(flag_key: "float", default_value: 0.0)

        expect(fetched.value).to eq(1.0)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
      end
    end

    context "when flag is not found" do
      it "returns default as flag not found" do
        fetched = provider.fetch_number_value(flag_key: "not here", default_value: 0)

        expect(fetched.value).to eq(0)
        expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end
    end
  end

  describe "#fetch_integer_value" do
    context "when flag is found" do
      it "returns value as static" do
        fetched = provider.fetch_integer_value(flag_key: "int", default_value: 0)

        expect(fetched.value).to eq(1)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
      end
    end

    context "when flag is not found" do
      it "returns default as flag not found" do
        fetched = provider.fetch_integer_value(flag_key: "not here", default_value: 0)

        expect(fetched.value).to eq(0)
        expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end
    end
  end

  describe "#fetch_float_value" do
    context "when flag is found" do
      it "returns value as static" do
        fetched = provider.fetch_float_value(flag_key: "float", default_value: 0.0)

        expect(fetched.value).to eq(1.0)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
      end
    end

    context "when flag is not found" do
      it "returns default as flag not found" do
        fetched = provider.fetch_float_value(flag_key: "not here", default_value: 0)

        expect(fetched.value).to eq(0)
        expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end
    end
  end

  describe "#fetch_object_value" do
    context "when flag is found" do
      it "returns value as static" do
        fetched = provider.fetch_object_value(flag_key: "struct", default_value: {})

        expect(fetched.value).to eq({"more" => "config"})
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
      end
    end

    context "when flag is not found" do
      it "returns default as flag not found" do
        fetched = provider.fetch_object_value(flag_key: "not here", default_value: {})

        expect(fetched.value).to eq({})
        expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
        expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end
    end
  end

  describe "variant flags" do
    let(:flag_class) { described_class::Flag }
    let(:metadata) { {"team" => "growth"} }
    let(:reason) { OpenFeature::SDK::Provider::Reason }

    def fetch_string(flag, evaluation_context: nil)
      described_class.new({"f" => flag}).fetch_string_value(flag_key: "f", default_value: "fallback", evaluation_context:)
    end

    def targeted_flag(evaluator)
      flag_class.new(variants: {"gold" => "shiny", "plain" => "dull"}, default_variant: "plain", context_evaluator: evaluator, flag_metadata: metadata)
    end

    it "returns the default value with reason DISABLED when the flag is disabled" do
      fetched = fetch_string(flag_class.new(variants: {"on" => "yes"}, default_variant: "on", flag_metadata: metadata, disabled: true))

      expect(fetched).to have_attributes(value: "fallback", variant: nil, reason: reason::DISABLED, error_code: nil, flag_metadata: metadata)
    end

    ["off", nil].each do |default_variant|
      it "returns PARSE_ERROR when the default variant is #{default_variant.inspect}" do
        fetched = fetch_string(flag_class.new(variants: {"on" => "yes"}, default_variant:, flag_metadata: metadata))

        expect(fetched).to have_attributes(
          value: "fallback", variant: nil, reason: reason::ERROR,
          error_code: OpenFeature::SDK::Provider::ErrorCode::PARSE_ERROR, flag_metadata: metadata
        )
      end
    end

    it "returns the matched variant with reason TARGETING_MATCH" do
      flag = targeted_flag(->(ctx) { (ctx&.targeting_key == "vip") ? "gold" : nil })

      fetched = fetch_string(flag, evaluation_context: OpenFeature::SDK::EvaluationContext.new(targeting_key: "vip"))

      expect(fetched).to have_attributes(value: "shiny", variant: "gold", reason: reason::TARGETING_MATCH, error_code: nil, flag_metadata: metadata)
    end

    [nil, "", "unknown"].each do |result|
      it "falls back to the default variant with reason DEFAULT when the evaluator returns #{result.inspect}" do
        fetched = fetch_string(targeted_flag(->(_ctx) { result }))

        expect(fetched).to have_attributes(value: "dull", variant: "plain", reason: reason::DEFAULT, error_code: nil, flag_metadata: metadata)
      end
    end

    it "returns the default variant with reason STATIC when there is no evaluator" do
      fetched = fetch_string(flag_class.new(variants: {"on" => "yes"}, default_variant: "on", flag_metadata: metadata))

      expect(fetched).to have_attributes(value: "yes", variant: "on", reason: reason::STATIC, error_code: nil, flag_metadata: metadata)
    end

    it "resolves a falsy variant value" do
      flag = flag_class.new(variants: {"zero" => false, "one" => true}, default_variant: "one", context_evaluator: ->(_ctx) { "zero" })

      fetched = described_class.new({"f" => flag}).fetch_boolean_value(flag_key: "f", default_value: true)

      expect(fetched).to have_attributes(value: false, variant: "zero", reason: reason::TARGETING_MATCH)
    end

    it "returns a plain Hash flag value as-is" do
      raw = {"variants" => {"a" => 1}}

      fetched = described_class.new({"f" => raw}).fetch_object_value(flag_key: "f", default_value: {})

      expect(fetched).to have_attributes(value: raw, reason: reason::STATIC)
    end

    it "emits PROVIDER_CONFIGURATION_CHANGED when Flag values are updated" do
      config = instance_double("OpenFeature::SDK::Configuration")
      allow(config).to receive(:dispatch_provider_event)
      provider.send(:attach, config)

      provider.update_flags({"f" => flag_class.new(variants: {"on" => "yes"}, default_variant: "on")})

      expect(config).to have_received(:dispatch_provider_event).with(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED,
        flags_changed: contain_exactly("bool", "str", "int", "float", "struct", "f")
      )
    end
  end
end
