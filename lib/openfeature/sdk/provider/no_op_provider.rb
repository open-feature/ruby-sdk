# frozen_string_literal: true
# typed: true

# frozen_literal: true

require "sorbet-runtime"
require "json"

require_relative("./provider")
require_relative("../metadata")
require_relative("../evaluation_context")
require_relative("../resolution_details")

# rubocop:disable Lint/UnusedMethodArgument
module OpenFeature
  module SDK
    module Provider
      # TODO: Write documentation
      #
      class NoOpProvider
        extend T::Sig
        include Provider

        Number = T.type_alias { T.any(Integer, Float) }

        REASON_NO_OP = "No-op"
        NAME = "No-op Provider"

        def initialize
          @metadata = SDK::Metadata.new(name: NAME).freeze
        end

        sig do
          override.params(
            flag_key: String,
            default_value: T::Boolean,
            evaluation_context: T.nilable(EvaluationContext)
          ).returns(ResolutionDetails)
        end
        def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        sig do
          override.params(
            flag_key: String,
            default_value: String,
            evaluation_context: T.nilable(EvaluationContext)
          ).returns(ResolutionDetails)
        end
        def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        sig do
          override.params(
            flag_key: String,
            default_value: Number,
            evaluation_context: T.nilable(EvaluationContext)
          ).returns(ResolutionDetails)
        end
        def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        sig do
          override.params(
            flag_key: String,
            default_value: T.untyped,
            evaluation_context: T.nilable(EvaluationContext)
          ).returns(ResolutionDetails)
        end
        def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        private

        sig { params(default_value: T.untyped, variant: T.nilable(String)).returns(ResolutionDetails) }
        def no_op(default_value)
          ResolutionDetails.new(value: default_value, reason: REASON_NO_OP)
        end
      end
    end
  end
end
# rubocop:enable Lint/UnusedMethodArgument
