# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require_relative("./feature_flag_error_code")

class FeatureFlagEvaluationDetails < T::Struct
  const :reason, T.nilable(String)
  const :variant, T.nilable(String)
  const :error_code, T.nilable(FeatureFlagErrorCode)
  const :error_message, T.nilable(String)
end
