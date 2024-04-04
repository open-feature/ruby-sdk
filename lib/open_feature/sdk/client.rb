# frozen_string_literal: true

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Client
      RESULT_TYPE = %i[boolean string number object].freeze
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
              built_context = EvaluationContextBuilder.new.call(api_context: OpenFeature::SDK.evaluation_context, client_context: self.evaluation_context, invocation_context: evaluation_context)
              resolution_details = @provider.fetch_#{result_type}_value(flag_key:, default_value:, evaluation_context: built_context)
              evaluation_details = EvaluationDetails.new(flag_key:, resolution_details:)
              #{"evaluation_details.value" if suffix == :value}
            end
          RUBY
        end
      end
    end
  end
end
