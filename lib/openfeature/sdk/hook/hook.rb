# frozen_string_literal: true
# typed: true

require "sorbet-runtime"

require_relative("./hook_context")

module Hook
  extend T::Sig
  extend T::Helpers
  interface!

  sig do
    abstract.params(
      hook_context: HookContext,
      hook_hints: T.nilable(T::Hash[Symbol, T.untyped])
    ).returns(EvaluationContext)
  end
  def before(hook_context:, hook_hints: nil); end

  sig do
    abstract.params(
      hook_context: HookContext,
      hook_hints: T.nilable(T::Hash[Symbol, T.untyped])
    ).returns(EvaluationContext)
  end
  def after(hook_context:, hook_hints: nil); end

  sig do
    abstract.params(
      hook_context: HookContext,
      hook_hints: T.nilable(T::Hash[Symbol, T.untyped])
    ).returns(EvaluationContext)
  end
  def error(hook_context:, hook_hints: nil); end

  sig do
    abstract.params(
      hook_context: HookContext,
      hook_hints: T.nilable(T::Hash[Symbol, T.untyped])
    ).returns(EvaluationContext)
  end
  def finally(hook_context:, hook_hints: nil); end
end
