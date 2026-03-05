# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Hooks::Hook do
  let(:hook_class) do
    Class.new do
      include OpenFeature::SDK::Hooks::Hook
    end
  end

  subject(:hook) { hook_class.new }

  describe "default implementations" do
    it "before returns nil by default" do
      result = hook.before(hook_context: double, hints: double)
      expect(result).to be_nil
    end

    it "after returns nil by default" do
      result = hook.after(hook_context: double, evaluation_details: double, hints: double)
      expect(result).to be_nil
    end

    it "error returns nil by default" do
      result = hook.error(hook_context: double, exception: double, hints: double)
      expect(result).to be_nil
    end

    it "finally returns nil by default" do
      result = hook.finally(hook_context: double, evaluation_details: double, hints: double)
      expect(result).to be_nil
    end
  end

  describe "overriding stages" do
    let(:custom_hook_class) do
      Class.new do
        include OpenFeature::SDK::Hooks::Hook

        def before(hook_context:, hints:)
          OpenFeature::SDK::EvaluationContext.new(custom_key: "custom_value")
        end
      end
    end

    it "allows overriding specific stages" do
      custom_hook = custom_hook_class.new
      result = custom_hook.before(hook_context: double, hints: double)
      expect(result).to be_a(OpenFeature::SDK::EvaluationContext)
      expect(result.field("custom_key")).to eq("custom_value")
    end

    it "keeps default implementations for non-overridden stages" do
      custom_hook = custom_hook_class.new
      expect(custom_hook.after(hook_context: double, evaluation_details: double, hints: double)).to be_nil
      expect(custom_hook.error(hook_context: double, exception: double, hints: double)).to be_nil
      expect(custom_hook.finally(hook_context: double, evaluation_details: double, hints: double)).to be_nil
    end
  end
end
