# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require_relative("./hook/hook")

class EvaluationOptions < T::Struct
  const :hooks, T::Array[Hook], default: []
  const :hook_hints, T.nilable(T::Hash[String, T.untyped])
end
