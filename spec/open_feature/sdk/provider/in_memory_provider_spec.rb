require "spec_helper"

RSpec.describe OpenFeature::SDK::Provider::InMemoryProvider do
  subject(:provider) do
    described_class.new(
      {
        "bool" => true,
        "str" => "testing",
        "num" => 1,
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
  end

  describe "#fetch_boolean_value" do
    context "when flag is found" do
      context "when type matches" do
        it "returns value as static" do
          fetched = provider.fetch_boolean_value(flag_key: "bool", default_value: false)

          expect(fetched.value).to eq(true)
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
        end
      end

      context "when type does not match" do
        it "returns default as type mismatch" do
          fetched = provider.fetch_boolean_value(flag_key: "str", default_value: false)

          expect(fetched.value).to eq(false)
          expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
        end
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
      context "when type matches" do
        it "returns value as static" do
          fetched = provider.fetch_string_value(flag_key: "str", default_value: "fallback")

          expect(fetched.value).to eq("testing")
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
        end
      end

      context "when type does not match" do
        it "returns default as type mismatch" do
          fetched = provider.fetch_string_value(flag_key: "bool", default_value: "fallback")

          expect(fetched.value).to eq("fallback")
          expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
        end
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
      context "when type matches" do
        it "returns value as static" do
          fetched = provider.fetch_number_value(flag_key: "num", default_value: 0)

          expect(fetched.value).to eq(1)
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
        end
      end

      context "when type does not match" do
        it "returns default as type mismatch" do
          fetched = provider.fetch_number_value(flag_key: "str", default_value: 0)

          expect(fetched.value).to eq(0)
          expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
        end
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

  describe "#fetch_object_value" do
    context "when flag is found" do
      context "when type matches" do
        it "returns value as static" do
          fetched = provider.fetch_object_value(flag_key: "struct", default_value: {})

          expect(fetched.value).to eq({"more" => "config"})
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::STATIC)
        end
      end

      context "when type does not match" do
        it "returns default as type mismatch" do
          fetched = provider.fetch_object_value(flag_key: "num", default_value: {})

          expect(fetched.value).to eq({})
          expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
          expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
        end
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
