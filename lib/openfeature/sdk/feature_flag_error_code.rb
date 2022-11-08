# frozen_string_literal: true
# typed: true

require "sorbet-runtime"

class FeatureFlagErrorCode < T::Enum
  enums do
    PROVIDER_NOT_READY = new("PROVIDER_NOT_READY")
    FLAG_NOT_FOUND = new("FLAG_NOT_FOUND")
    PARSE_ERROR = new("PARSE_ERROR")
    TYPE_MISMATCH = new("TYPE_MISMATCH")
    TARGETING_KEY_MISSING = new("TARGETING_KEY_MISSING")
    INVALID_CONTEXT = new("INVALID_CONTEXT")
    GENERAL = new("GENERAL")
  end
end
