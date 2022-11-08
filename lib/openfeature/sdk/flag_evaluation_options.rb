# frozen_string_literal: true
# typed: true

require "sorbet-runtime"
require_relative("./hook")

class FlagEvaluationOptions < T::Struct
  const :hooks, T.nilable(T::Array[Hook])
  const :hook_hints, T.nilable(T::Hash[String, T.untyped])
end
