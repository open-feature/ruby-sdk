# frozen_string_literal: true

require_relative "provider/error_code"

module OpenFeature
  module SDK
    # Raised by a provider to signal an evaluation error with an OpenFeature
    # error code (spec 2.2.7). Any exception responding to +error_code+ is
    # honored the same way.
    class EvaluationError < StandardError
      # @return [String] the OpenFeature error code
      attr_reader :error_code

      def initialize(message = nil, error_code: Provider::ErrorCode::GENERAL)
        super(message || error_code)
        @error_code = error_code
      end
    end
  end
end
