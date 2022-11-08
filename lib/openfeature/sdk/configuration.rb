# frozen_string_literal: true
# typed: true

require "forwardable"

require_relative "./provider/provider"
require_relative "./provider/no_op_provider"

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Configuration
      extend T::Sig
      extend Forwardable

      sig { returns(T.nilable(EvaluationContext)) }
      attr_accessor :context

      sig { returns(SDK::Provider) }
      attr_accessor :provider

      sig { returns(T::Array[Hook]) }
      attr_accessor :hooks

      def_delegator :@provider, :metadata

      def initialize
        @hooks = []
      end
    end
  end
end
