# frozen_string_literal: true

require "concurrent"
require "forwardable"

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Client

      RESULT_TYPE = %i(boolean string number object).freeze
      SUFFIXES = %i(value details)


      attr_reader :metadata

      attr_accessor :hooks

      def initialize(provider:, client_options: nil, context: nil)
        @provider = provider
        @metadata = client_options
        @context = context
        @hooks = Concurrent::Array.new([])
      end


      RESULT_TYPE.each do |result_type|
        SUFFIXES.each do |suffix|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def fetch_#{result_type}_#{suffix}(flag_key:, default_value:, evaluation_context: nil)
              evaluate_flag_#{suffix}(flag_type: #{result_type.inspect}, flag_key: flag_key, default_value: default_value,
                evaluation_context: evaluation_context)
            end
          RUBY
        end
      end

      def evaluate_flag_details(flag_type:, flag_key:, default_value:, evaluation_context: nil)
        case flag_type
        when :boolean
          @provider.fetch_boolean_value(flag_key: flag_key, default_value: default_value,
                                        evaluation_context: evaluation_context)
        when :number
          @provider.fetch_number_value(flag_key: flag_key, default_value: default_value,
                                       evaluation_context: evaluation_context)
        when :string
          @provider.fetch_string_value(flag_key: flag_key, default_value: default_value,
                                       evaluation_context: evaluation_context)
        when :object
          @provider.fetch_object_value(flag_key: flag_key, default_value: default_value,
                                       evaluation_context: evaluation_context)
        else
          raise ArgumentError.new("Unsupported flag_type: #{flag_type}")
        end
      end

      def evaluate_flag_value(flag_type:, flag_key:, default_value:, evaluation_context: nil)
        details = evaluate_flag_details(flag_key: flag_key, flag_type: flag_type, default_value: default_value, evaluation_context: evaluation_context)
        details.value
      end
    end
  end
end
