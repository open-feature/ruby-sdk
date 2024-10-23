# frozen_string_literal: true

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Client
      attr_reader :metadata, :evaluation_context

      attr_accessor :hooks

      def initialize(provider:, domain: nil, evaluation_context: nil)
        @provider = provider
        @metadata = ClientMetadata.new(domain:)
        @evaluation_context = evaluation_context
        @hooks = []
      end

      def fetch_boolean_details(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :boolean, flag_key:, default_value:, evaluation_context:)
      end

      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :boolean, flag_key:, default_value:, evaluation_context:).value
      end

      def fetch_string_details(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :string, flag_key:, default_value:, evaluation_context:)
      end

      def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :string, flag_key:, default_value:, evaluation_context:).value
      end

      def fetch_number_details(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :number, flag_key:, default_value:, evaluation_context:)
      end

      def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :number, flag_key:, default_value:, evaluation_context:).value
      end

      def fetch_integer_details(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :integer, flag_key:, default_value:, evaluation_context:)
      end

      def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :integer, flag_key:, default_value:, evaluation_context:).value
      end

      def fetch_float_details(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :float, flag_key:, default_value:, evaluation_context:)
      end

      def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :float, flag_key:, default_value:, evaluation_context:).value
      end

      def fetch_object_details(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :object, flag_key:, default_value:, evaluation_context:)
      end

      def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
        fetch_details(type: :object, flag_key:, default_value:, evaluation_context:).value
      end

      private

      def fetch_details(type:, flag_key:, default_value:, evaluation_context: nil)
        built_context = EvaluationContextBuilder.new.call(api_context: OpenFeature::SDK.evaluation_context, client_context: self.evaluation_context, invocation_context: evaluation_context)

        EvaluationDetails.new(
          flag_key:,
          resolution_details: @provider.send(:"fetch_#{type}_value", flag_key:, default_value:, evaluation_context: built_context)
        )
      end
    end
  end
end
