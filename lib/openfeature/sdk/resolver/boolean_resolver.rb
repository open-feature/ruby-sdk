# frozen_string_literal: true
# typed: true

require "sorbet-runtime"

require_relative "../provider/provider"
require_relative "../evaluation_context"
require_relative "../metadata"
require_relative "../hook/hook"
require_relative "../hook/hook_context"
require_relative "../evaluation_options"

module OpenFeature
  module Resolver
    # TODO: Write documentation
    #
    class BooleanResolver
      extend T::Sig

      sig do
        params(
          provider: SDK::Provider
        ).void
      end
      def initialize(provider)
        @provider = provider
      end

      sig do
        params(
          flag_key: String,
          default_value: T::Boolean,
          evaluation_context: T.nilable(EvaluationContext),
          evaluation_options: T.nilable(EvaluationOptions)
        ).returns(T::Boolean)
      end
      def fetch_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        resolution_details = @provider.fetch_boolean_value(flag_key: flag_key, default_value: default_value, evaluation_context: evaluation_context, evaluation_options: evaluation_options)
        correct_type?(resolution_details.value) ? resolution_details.value : default_value
      end

      sig do
        params(
          flag_key: String,
          default_value: T::Boolean,
          evaluation_context: T.nilable(EvaluationContext),
          evaluation_options: T.nilable(EvaluationOptions)
        ).returns(ResolutionDetails)
      end
      def fetch_detailed_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        @provider.fetch_boolean_value(flag_key: flag_key, default_value: default_value, evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      private

      sig { params(value: T.untyped).returns(T::Boolean) }
      def correct_type?(value)
        [TrueClass, FalseClass].include?(value.class)
      end
    end
  end
end
