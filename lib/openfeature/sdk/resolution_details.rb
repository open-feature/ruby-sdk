# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require_relative("./feature_flag_error_code")
require_relative("./resolution_reason")

class ResolutionDetails < T::Struct
  const :value, T.any(String, T::Boolean, Integer, Float, T::Hash[String, T.untyped], T::Array[T.untyped])
  const :reason, T.nilable(T.any(ResolutionReason, String))
  const :variant, T.nilable(String)
  const :error_code, T.nilable(FeatureFlagErrorCode)
  const :error_message, T.nilable(String)
end
