# frozen_string_literal: true

require_relative "../metadata"

# rubocop:disable Lint/UnusedMethodArgument
module OpenFeature
  module SDK
    module Provider
      # Defines the default provider that is set if no provider is specified.
      #
      # To use <tt>NoOpProvider</tt>, it can be set during the configuration of the SDK
      #
      #   OpenFeature::SDK.configure do |config|
      #     config.provider = NoOpProvider.new
      #   end
      #
      # Within the <tt>NoOpProvider</tt>, the following methods exist
      #
      # * <tt>fetch_boolean_value</tt> - Retrieve feature flag boolean value
      #
      # * <tt>fetch_string_value</tt> - Retrieve feature flag string value
      #
      # * <tt>fetch_number_value</tt> - Retrieve feature flag number value
      #
      # * <tt>fetch_object_value</tt> - Retrieve feature flag object value
      #
      class NoOpProvider
        REASON_NO_OP = "No-op"
        NAME = "No-op Provider"

        attr_reader :metadata

        def initialize
          @metadata = Metadata.new(name: NAME).freeze
        end

        def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
          no_op(default_value)
        end

        private

        def no_op(default_value)
          ResolutionDetails.new(value: default_value, reason: REASON_NO_OP)
        end
      end
    end
  end
end
# rubocop:enable Lint/UnusedMethodArgument
