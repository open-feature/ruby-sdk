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
      it "emits PROVIDER_CONFIGURATION_CHANGED event with all flag keys" do
        config = instance_double("OpenFeature::SDK::Configuration")
        allow(config).to receive(:dispatch_provider_event)
        provider.send(:attach, config)

        provider.update_flags({"flag_a" => true, "flag_b" => false})

        expect(config).to have_received(:dispatch_provider_event).with(
          provider,
          OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED,
          flags_changed: contain_exactly("flag_a", "flag_b")
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
end
