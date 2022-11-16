# frozen_string_literal: true

require "concurrent"
require "forwardable"

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Client
      extend Forwardable

      attr_reader :metadata

      attr_accessor :hooks

      def initialize(provider:, client_options: nil, context: nil)
        @provider = provider
        @metadata = client_options
        @context = context
        @hooks = Concurrent::Array.new([])
      end

      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      def fetch_boolean_details(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      def fetch_string_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      def fetch_string_details(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      def fetch_number_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      def fetch_number_details(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      def fetch_object_value(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
      end

      def fetch_object_details(flag_key:, default_value:, evaluation_context: nil, evaluation_options: nil)
        evaluate_flag_details(flag_type: :boolean, flag_key: flag_key, default_value: default_value,
                              evaluation_context: evaluation_context, evaluation_options: evaluation_options)
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
          StandardError.new("Unsupported flag_type")
        end
      end
    end
  end
end
