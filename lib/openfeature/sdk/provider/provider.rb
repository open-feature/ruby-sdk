# frozen_string_literal: true
# typed: true

# frozen_literal: true

require "sorbet-runtime"
require_relative("../feature_flag_evaluation_details")
require_relative("../evaluation_context")
require_relative("../hook/hook")

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    module Provider
      extend T::Sig
      extend T::Helpers
      interface!

      Number = T.type_alias { T.any(Integer, Float) }

      sig { returns(Metadata) }
      attr_reader :metadata

      sig { returns(T.nilable(T::Array[Hook])) }
      attr_accessor :hooks

      sig do
        abstract.params(
          flag_key: String,
          default_value: T::Boolean,
          evaluation_context: T.nilable(EvaluationContext)
        ).returns(ResolutionDetails)
      end
      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil); end

      sig do
        abstract.params(
          flag_key: String,
          default_value: T::Boolean,
          evaluation_details: FeatureFlagEvaluationDetails
        ).returns(ResolutionDetails)
      end
      def fetch_boolean_details(flag_key:, default_value:, evaluation_details:); end

      sig do
        abstract.params(
          flag_key: String,
          default_value: String,
          evaluation_context: T.nilable(EvaluationContext)
        ).returns(ResolutionDetails)
      end
      def fetch_string_value(flag_key:, default_value:, evaluation_context: nil); end

      sig do
        abstract.params(
          flag_key: String,
          default_value: String,
          evaluation_details: FeatureFlagEvaluationDetails
        ).returns(ResolutionDetails)
      end
      def fetch_string_details(flag_key:, default_value:, evaluation_details:); end

      sig do
        abstract.params(
          flag_key: String,
          default_value: Number,
          evaluation_context: T.nilable(EvaluationContext)
        ).returns(ResolutionDetails)
      end
      def fetch_number_value(flag_key:, default_value:, evaluation_context: nil); end

      sig do
        abstract.params(
          flag_key: String,
          default_value: Number,
          evaluation_details: FeatureFlagEvaluationDetails
        ).returns(ResolutionDetails)
      end
      def fetch_number_details(flag_key:, default_value:, evaluation_details:); end

      sig do
        abstract.params(
          flag_key: String,
          default_value: T.untyped,
          evaluation_context: T.nilable(EvaluationContext)
        ).returns(ResolutionDetails)
      end
      def fetch_object_value(flag_key:, default_value:, evaluation_context: nil); end

      sig do
        abstract.params(
          flag_key: String,
          default_value: T.untyped,
          evaluation_details: FeatureFlagEvaluationDetails
        ).returns(Object)
      end
      def fetch_object_details(flag_key:, default_value:, evaluation_details:); end
    end
  end
end
