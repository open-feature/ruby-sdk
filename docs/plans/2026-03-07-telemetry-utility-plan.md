# Telemetry Utility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a dependency-free `OpenFeature::SDK::Telemetry` module that creates OTel-compatible evaluation events from hook context and evaluation details.

**Architecture:** Single module (`Telemetry`) in one file with constants, a Struct, and one public `module_function`. Designed for consumption in a hook's `finally` stage. No third-party dependencies.

**Tech Stack:** Ruby >= 3.1, RSpec, Standard Ruby (linter)

---

### Task 1: Create telemetry module with constants and struct

**Files:**
- Create: `lib/open_feature/sdk/telemetry.rb`

**Step 1: Create the module file with constants and struct**

```ruby
# frozen_string_literal: true

module OpenFeature
  module SDK
    module Telemetry
      EVENT_NAME = "feature_flag.evaluation"

      FLAG_KEY = "feature_flag.key"
      CONTEXT_ID_KEY = "feature_flag.context.id"
      ERROR_MESSAGE_KEY = "error.message"
      ERROR_TYPE_KEY = "error.type"
      PROVIDER_NAME_KEY = "feature_flag.provider.name"
      RESULT_REASON_KEY = "feature_flag.result.reason"
      RESULT_VALUE_KEY = "feature_flag.result.value"
      RESULT_VARIANT_KEY = "feature_flag.result.variant"
      FLAG_SET_ID_KEY = "feature_flag.set.id"
      VERSION_KEY = "feature_flag.version"

      METADATA_KEY_MAP = {
        "contextId" => CONTEXT_ID_KEY,
        "flagSetId" => FLAG_SET_ID_KEY,
        "version" => VERSION_KEY
      }.freeze

      EvaluationEvent = Struct.new(:name, :attributes, keyword_init: true)
    end
  end
end
```

**Step 2: Wire up the require**

Modify: `lib/open_feature/sdk.rb` — add `require_relative "sdk/telemetry"` after the existing requires (line 3 area).

**Step 3: Verify it loads**

Run: `bundle exec ruby -e "require 'open_feature/sdk'; puts OpenFeature::SDK::Telemetry::EVENT_NAME"`
Expected: `feature_flag.evaluation`

**Step 4: Commit**

```bash
git add lib/open_feature/sdk/telemetry.rb lib/open_feature/sdk.rb
git commit -s -S -m "feat(telemetry): add Telemetry module with OTel constants and EvaluationEvent struct"
```

---

### Task 2: Write tests for happy path and return type

**Files:**
- Create: `spec/open_feature/sdk/telemetry_spec.rb`

**Step 1: Write the test file with happy path and return type tests**

```ruby
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
  end
end
```

**Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/open_feature/sdk/telemetry_spec.rb`
Expected: FAIL — `NoMethodError: undefined method 'create_evaluation_event'`

**Step 3: Commit the failing test**

```bash
git add spec/open_feature/sdk/telemetry_spec.rb
git commit -s -S -m "test(telemetry): add failing test for happy path"
```

---

### Task 3: Implement create_evaluation_event

**Files:**
- Modify: `lib/open_feature/sdk/telemetry.rb`

**Step 1: Add the implementation to the Telemetry module**

Add after the `EvaluationEvent` struct definition:

```ruby
      module_function

      def create_evaluation_event(hook_context:, evaluation_details:)
        attributes = {FLAG_KEY => hook_context.flag_key}

        provider_name = hook_context.provider_metadata&.name
        attributes[PROVIDER_NAME_KEY] = provider_name if provider_name

        targeting_key = hook_context.evaluation_context&.targeting_key
        attributes[CONTEXT_ID_KEY] = targeting_key if targeting_key

        if evaluation_details
          if evaluation_details.variant
            attributes[RESULT_VARIANT_KEY] = evaluation_details.variant
          else
            attributes[RESULT_VALUE_KEY] = evaluation_details.value
          end

          if evaluation_details.reason
            attributes[RESULT_REASON_KEY] = evaluation_details.reason.downcase
          end

          if evaluation_details.error_code
            attributes[ERROR_TYPE_KEY] = evaluation_details.error_code.downcase
          end

          if evaluation_details.error_message
            attributes[ERROR_MESSAGE_KEY] = evaluation_details.error_message
          end

          extract_metadata(evaluation_details.flag_metadata, attributes)
        end

        EvaluationEvent.new(name: EVENT_NAME, attributes: attributes)
      end

      def extract_metadata(flag_metadata, attributes)
        return unless flag_metadata

        METADATA_KEY_MAP.each do |metadata_key, otel_key|
          value = flag_metadata[metadata_key]
          attributes[otel_key] = value unless value.nil?
        end
      end

      private_class_method :extract_metadata
```

**Step 2: Run the test to verify it passes**

Run: `bundle exec rspec spec/open_feature/sdk/telemetry_spec.rb`
Expected: PASS (1 example, 0 failures)

**Step 3: Commit**

```bash
git add lib/open_feature/sdk/telemetry.rb
git commit -s -S -m "feat(telemetry): implement create_evaluation_event"
```

---

### Task 4: Add tests for variant vs value precedence

**Files:**
- Modify: `spec/open_feature/sdk/telemetry_spec.rb`

**Step 1: Add variant/value precedence tests**

Add inside the `describe ".create_evaluation_event"` block:

```ruby
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
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/open_feature/sdk/telemetry_spec.rb`
Expected: PASS (3 examples, 0 failures)

**Step 3: Commit**

```bash
git add spec/open_feature/sdk/telemetry_spec.rb
git commit -s -S -m "test(telemetry): add variant vs value precedence tests"
```

---

### Task 5: Add tests for enum downcasing

**Files:**
- Modify: `spec/open_feature/sdk/telemetry_spec.rb`

**Step 1: Add enum downcasing tests**

Add inside the `describe ".create_evaluation_event"` block:

```ruby
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
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/open_feature/sdk/telemetry_spec.rb`
Expected: PASS (5 examples, 0 failures)

**Step 3: Commit**

```bash
git add spec/open_feature/sdk/telemetry_spec.rb
git commit -s -S -m "test(telemetry): add enum downcasing tests"
```

---

### Task 6: Add tests for error attributes and nil evaluation_details

**Files:**
- Modify: `spec/open_feature/sdk/telemetry_spec.rb`

**Step 1: Add error and nil evaluation_details tests**

Add inside the `describe ".create_evaluation_event"` block:

```ruby
    context "error attributes" do
      it "includes error attributes only when error occurred" do
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: false,
          reason: "ERROR",
          error_code: "PARSE_ERROR",
          error_message: "Could not parse flag"
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "bad-flag",
          resolution_details: resolution
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
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/open_feature/sdk/telemetry_spec.rb`
Expected: PASS (8 examples, 0 failures)

**Step 3: Commit**

```bash
git add spec/open_feature/sdk/telemetry_spec.rb
git commit -s -S -m "test(telemetry): add error attributes and nil evaluation_details tests"
```

---

### Task 7: Add tests for flag metadata and context ID precedence

**Files:**
- Modify: `spec/open_feature/sdk/telemetry_spec.rb`

**Step 1: Add metadata and context ID tests**

Add inside the `describe ".create_evaluation_event"` block:

```ruby
    context "flag metadata" do
      it "ignores nil flag_metadata" do
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: true,
          variant: "on"
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "my-flag",
          resolution_details: resolution
        )

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes).not_to have_key("feature_flag.set.id")
        expect(event.attributes).not_to have_key("feature_flag.version")
      end

      it "ignores empty flag_metadata" do
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: true,
          variant: "on",
          flag_metadata: {}
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "my-flag",
          resolution_details: resolution
        )

        event = described_class.create_evaluation_event(
          hook_context: hook_context,
          evaluation_details: details
        )

        expect(event.attributes).not_to have_key("feature_flag.set.id")
        expect(event.attributes).not_to have_key("feature_flag.version")
      end

      it "ignores unknown metadata keys" do
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: true,
          variant: "on",
          flag_metadata: {"customKey" => "custom-value", "anotherKey" => 42}
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "my-flag",
          resolution_details: resolution
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
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: true,
          variant: "on",
          flag_metadata: {"flagSetId" => "set-1"}
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "my-flag",
          resolution_details: resolution
        )

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
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: true,
          variant: "on"
        )
        details = OpenFeature::SDK::EvaluationDetails.new(
          flag_key: "my-flag",
          resolution_details: resolution
        )

        event = described_class.create_evaluation_event(
          hook_context: bare_hook_context,
          evaluation_details: details
        )

        expect(event.attributes).not_to have_key("feature_flag.context.id")
      end
    end
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/open_feature/sdk/telemetry_spec.rb`
Expected: PASS (14 examples, 0 failures)

**Step 3: Commit**

```bash
git add spec/open_feature/sdk/telemetry_spec.rb
git commit -s -S -m "test(telemetry): add flag metadata and context ID precedence tests"
```

---

### Task 8: Run full suite and lint

**Step 1: Run full test suite**

Run: `bundle exec rspec`
Expected: All existing tests still pass, plus 14 new telemetry tests.

**Step 2: Run linter**

Run: `bundle exec standardrb`
Expected: No offenses. If any, fix with `bundle exec standardrb --fix`.

**Step 3: Final commit if lint fixes needed**

```bash
git add -A
git commit -s -S -m "style(telemetry): fix standardrb lint issues"
```
