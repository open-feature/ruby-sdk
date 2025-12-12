# frozen_string_literal: true

require_relative "provider/error_code"

module OpenFeature
  module SDK
    # Exception raised when a provider fails to initialize during setProviderAndWait
    #
    # This exception provides access to both the original error that caused the
    # initialization failure and the provider instance that failed to initialize.
    class ProviderInitializationError < StandardError
      # @return [Object] the provider that failed to initialize
      attr_reader :provider

      # @return [Exception] the original error that caused the initialization failure
      attr_reader :original_error

      # @return [String] the OpenFeature error code
      attr_reader :error_code

      # @param message [String] the error message
      # @param provider [Object] the provider that failed to initialize
      # @param original_error [Exception] the original error that caused the failure
      # @param error_code [String] the OpenFeature error code (defaults to PROVIDER_FATAL)
      def initialize(message, provider: nil, original_error: nil, error_code: Provider::ErrorCode::PROVIDER_FATAL)
        super(message)
        @provider = provider
        @original_error = original_error
        @error_code = error_code
      end
    end
  end
end
