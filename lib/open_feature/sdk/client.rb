# frozen_string_literal: true

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Client
      TYPE_CLASS_MAP = {
        boolean: [TrueClass, FalseClass],
        string: [String],
        number: [Numeric],
        integer: [Integer],
        float: [Float],
        object: [Array, Hash]
      }.freeze
      RESULT_TYPE = TYPE_CLASS_MAP.keys.freeze
      SUFFIXES = %i[value details].freeze

      attr_reader :metadata, :evaluation_context

      attr_accessor :hooks

      def initialize(provider:, domain: nil, evaluation_context: nil)
        @provider = provider
        @metadata = ClientMetadata.new(domain:)
        @evaluation_context = evaluation_context
        @hooks = []
      end

      RESULT_TYPE.each do |result_type|
        SUFFIXES.each do |suffix|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def fetch_boolean_details(flag_key:, default_value:, evaluation_context: nil)
            #   result = @provider.fetch_boolean_value(flag_key: flag_key, default_value: default_value, evaluation_context: evaluation_context)
            # end
            def fetch_#{result_type}_#{suffix}(flag_key:, default_value:, evaluation_context: nil)
              evaluation_details = fetch_details(type: :#{result_type}, flag_key:, default_value:, evaluation_context:)
              #{"evaluation_details.value" if suffix == :value}
            end
          RUBY
        end
      end

      private

      def fetch_details(type:, flag_key:, default_value:, evaluation_context: nil)
        built_context = EvaluationContextBuilder.new.call(api_context: OpenFeature::SDK.evaluation_context, client_context: self.evaluation_context, invocation_context: evaluation_context)

        resolution_details = @provider.send(:"fetch_#{type}_value", flag_key:, default_value:, evaluation_context: built_context)
        
        if TYPE_CLASS_MAP[type].none? { |klass| resolution_details.value.is_a?(klass) }
          resolution_details.value = default_value
          resolution_details.error_code = Provider::ErrorCode::TYPE_MISMATCH
          resolution_details.reason = Provider::Reason::ERROR
        end

        EvaluationDetails.new(flag_key:, resolution_details:)
      end
    end
  end
end
