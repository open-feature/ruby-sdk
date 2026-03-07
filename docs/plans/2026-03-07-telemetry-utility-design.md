# Telemetry Utility Design

## Overview

Add an OTel-compatible telemetry utility to the OpenFeature Ruby SDK that creates
structured evaluation events from hook context and evaluation details. This utility
is dependency-free (no OTel gem required) and follows the pattern established by
the Go SDK's `telemetry` package.

Addresses: https://github.com/open-feature/ruby-sdk/issues/176

## References

- [OpenFeature Spec Appendix D (Observability)](https://openfeature.dev/specification/appendix-d/)
- [OTel Semantic Conventions for Feature Flags](https://opentelemetry.io/docs/specs/semconv/feature-flags/feature-flags-logs/)
- [Go SDK telemetry package](https://github.com/open-feature/go-sdk/tree/main/openfeature/telemetry)
- [JS SDK reference PR](https://github.com/open-feature/js-sdk/pull/1120)

## Design Decisions

1. **Single public method** accepting `hook_context:` and `evaluation_details:` keyword
   arguments — mirrors the `finally` hook stage signature for zero-friction integration.
2. **Returns a Struct** (`EvaluationEvent`) with `name` and `attributes` fields — matches
   the SDK's existing Struct conventions (`ResolutionDetails`, `ClientMetadata`, etc.).
3. **Constants in the Telemetry module directly** — flat namespace matching Go SDK and
   existing Ruby SDK patterns (e.g., `Provider::Reason`).
4. **Hard-coded metadata mappings only** — maps `contextId`, `flagSetId`, `version` from
   flag metadata to OTel keys. Unknown metadata keys are ignored. Custom attributes can
   be added via hooks in ruby-sdk-contrib.
5. **No third-party dependencies** — pure data transformation using only standard library.

## File Structure

- `lib/open_feature/sdk/telemetry.rb` — module with constants, struct, and utility function
- `spec/open_feature/sdk/telemetry_spec.rb` — tests
- `lib/open_feature/sdk.rb` — add `require_relative "sdk/telemetry"`

## Constants

```ruby
EVENT_NAME        = "feature_flag.evaluation"

FLAG_KEY          = "feature_flag.key"
CONTEXT_ID_KEY    = "feature_flag.context.id"
ERROR_MESSAGE_KEY = "error.message"
ERROR_TYPE_KEY    = "error.type"
PROVIDER_NAME_KEY = "feature_flag.provider.name"
RESULT_REASON_KEY = "feature_flag.result.reason"
RESULT_VALUE_KEY  = "feature_flag.result.value"
RESULT_VARIANT_KEY = "feature_flag.result.variant"
FLAG_SET_ID_KEY   = "feature_flag.set.id"
VERSION_KEY       = "feature_flag.version"
```

## Public API

```ruby
OpenFeature::SDK::Telemetry.create_evaluation_event(
  hook_context:,        # Hooks::HookContext
  evaluation_details:   # EvaluationDetails or nil
) # => EvaluationEvent
```

Returns `EvaluationEvent = Struct.new(:name, :attributes, keyword_init: true)`.

## Attribute Population Rules

| Attribute | Source | Condition |
|-----------|--------|-----------|
| `feature_flag.key` | `hook_context.flag_key` | Always |
| `feature_flag.provider.name` | `hook_context.provider_metadata.name` | When present |
| `feature_flag.result.variant` | `evaluation_details.variant` | When present (takes precedence over value) |
| `feature_flag.result.value` | `evaluation_details.value` | Only when variant is nil |
| `feature_flag.result.reason` | `evaluation_details.reason.downcase` | When present |
| `error.type` | `evaluation_details.error_code.downcase` | When error occurred |
| `error.message` | `evaluation_details.error_message` | When error occurred |
| `feature_flag.context.id` | `targeting_key` or metadata `contextId` | Metadata takes precedence |
| `feature_flag.set.id` | metadata `flagSetId` | When present in flag_metadata |
| `feature_flag.version` | metadata `version` | When present in flag_metadata |

## Error Handling

No defensive `rescue` in the utility — it is a pure data transformation. Nil inputs
are handled via guard clauses. The calling hook is responsible for exception safety
(consistent with the existing hook executor pattern).

## Test Plan

1. Happy path with all attributes populated
2. Variant vs value precedence
3. Enum downcasing (reason and error_code)
4. Error attributes present only on error
5. Nil evaluation_details
6. Nil/empty flag_metadata
7. Metadata contextId overrides targeting_key
8. Targeting key fallback when no contextId
9. Unknown metadata keys ignored
10. Return type verification
