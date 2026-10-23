# frozen_string_literal: true

require_relative "provider/error_code"

module OpenFeature
  module SDK
    # What the SDK reports or logs, rather than raises, when provider, hook or handler code fails.
    # NotImplementedError isn't a StandardError, but it's Ruby's abstract-method idiom; Interrupt and the rest still propagate.
    RECOVERABLE_ERRORS = [StandardError, NotImplementedError].freeze

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

      # The error code carried by +exception+, or GENERAL when it has none.
      # Rescues a failing reader so callers inside a rescue block never raise (spec 1.4.10).
      def self.code_for(exception)
        (exception.respond_to?(:error_code) && exception.error_code) || Provider::ErrorCode::GENERAL
      rescue
        Provider::ErrorCode::GENERAL
      end
    end
  end
end
