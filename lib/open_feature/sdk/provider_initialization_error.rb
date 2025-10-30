# frozen_string_literal: true

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

      # @param message [String] the error message
      # @param provider [Object] the provider that failed to initialize
      # @param original_error [Exception] the original error that caused the failure
      def initialize(message, provider: nil, original_error: nil)
        super(message)
        @provider = provider
        @original_error = original_error
      end
    end
  end
end
