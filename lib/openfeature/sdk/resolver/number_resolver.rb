# frozen_string_literal: true
# typed: true

require "sorbet-runtime"
require_relative "../provider/provider"
require_relative("../evaluation_context")
require_relative("../metadata")
require_relative("../hook/hook")
require_relative("../hook/hook_context")
require_relative("../evaluation_options")

module OpenFeature
  module Resolver
    # TODO: Write documentation
    #
    class NumberResolver
      extend T::Sig

      Number = T.type_alias { T.any(Integer, Float) }

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
          default_value: Number,
          evaluation_context: T.nilable(EvaluationContext),
          evaluation_options: T.nilable(EvaluationOptions)
        ).returns(Number)
      end
      def fetch_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        resolution_details = @provider.fetch_number_value(flag_key: flag_key, default_value: default_value, evaluation_context: evaluation_context, evaluation_options: evaluation_options)
        correct_type?(resolution_details.value) ? resolution_details.value : default_value
      end

      sig do
        params(
          flag_key: String,
          default_value: Number,
          evaluation_context: T.nilable(EvaluationContext),
          evaluation_options: T.nilable(EvaluationOptions)
        ).returns(ResolutionDetails)
      end
      def fetch_detailed_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        @provider.fetch_number_value(flag_key: flag_key, default_value: default_value, evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      private

      def correct_type?(value)
        [Float, Integer].include?(value.class)
      end
    end
  end
end
