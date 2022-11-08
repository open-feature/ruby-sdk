# frozen_string_literal: true
# typed: true

require "sorbet-runtime"
require "forwardable"
require "json"

require_relative "./provider/provider"
require_relative "./evaluation_context"
require_relative "./metadata"
require_relative "./hook/hook"
require_relative "./hook/hook_context"
require_relative "./evaluation_options"
require_relative "./resolver/boolean_resolver"
require_relative "./resolver/number_resolver"
require_relative "./resolver/object_resolver"
require_relative "./resolver/string_resolver"

module OpenFeature
  module SDK
    # TODO: Write
    #
    class Client
      extend T::Sig
      extend Forwardable

      class OpenFeatureOptions < T::Struct
        const :name, T.nilable(String)
        const :version, T.nilable(String)
      end

      sig { returns(Metadata) }
      attr_reader :metadata

      sig { returns(T::Array[Hook]) }
      attr_accessor :hooks

      def_delegator :@boolean_resolver, :fetch_value, :fetch_boolean_value
      def_delegator :@boolean_resolver, :fetch_detailed_value, :fetch_boolean_details

      def_delegator :@number_resolver, :fetch_value, :fetch_number_value
      def_delegator :@number_resolver, :fetch_detailed_value, :fetch_number_details

      def_delegator :@string_resolver, :fetch_value, :fetch_string_value
      def_delegator :@string_resolver, :fetch_detailed_value, :fetch_string_details

      def_delegator :@object_resolver, :fetch_value, :fetch_object_value
      def_delegator :@object_resolver, :fetch_detailed_value, :fetch_object_details

      sig do
        params(
          provider: Provider,
          client_options: Metadata,
          context: T.nilable(EvaluationContext)
        ).void
      end
      def initialize(provider, client_options, context)
        @provider = provider
        @metadata = client_options.dup.freeze
        @context = context.dup.freeze
        @hooks = []

        @boolean_resolver = Resolver::BooleanResolver.new(provider)
        @number_resolver = Resolver::NumberResolver.new(provider)
        @string_resolver = Resolver::StringResolver.new(provider)
        @object_resolver = Resolver::ObjectResolver.new(provider)
      end
    end
  end
end
