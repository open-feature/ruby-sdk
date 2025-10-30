# frozen_string_literal: true

require 'timeout'
require_relative 'api'
require_relative 'provider_initialization_error'

module OpenFeature
  module SDK
    # Represents the configuration object for the global API where <tt>Provider</tt>, <tt>Hook</tt>,
    # and <tt>EvaluationContext</tt> are configured.
    # This class is not meant to be interacted with directly but instead through the <tt>OpenFeature::SDK.configure</tt>
    # method
    class Configuration
      extend Forwardable

      attr_accessor :evaluation_context, :hooks

      def initialize
        @hooks = []
        @providers = {}
        @provider_mutex = Mutex.new
      end

      def provider(domain: nil)
        @providers[domain] || @providers[nil]
      end

      # When switching providers, there are a few lifecycle methods that need to be taken care of.
      #   1. If a provider is already set, we need to call `shutdown` on it.
      #   2. On the new provider, call `init`.
      #   3. Finally, set the internal provider to the new provider
      def set_provider(provider, domain: nil)
        @provider_mutex.synchronize do
          @providers[domain].shutdown if @providers[domain].respond_to?(:shutdown)
          provider.init if provider.respond_to?(:init)
          new_providers = @providers.dup
          new_providers[domain] = provider
          @providers = new_providers
        end
      end

      # Sets a provider and waits for the initialization to complete or fail.
      # This method ensures the provider is ready (or in error state) before returning.
      #
      # @param provider [Object] the provider to set
      # @param domain [String, nil] the domain for the provider (optional)
      # @param timeout [Integer] maximum time to wait for initialization in seconds (default: 30)
      # @raise [ProviderInitializationError] if the provider fails to initialize or times out
      def set_provider_and_wait(provider, domain: nil, timeout: 30)
        @provider_mutex.synchronize do
          old_provider = @providers[domain]

          # Shutdown old provider (ignore errors)
          begin
            old_provider.shutdown if old_provider.respond_to?(:shutdown)
          rescue StandardError
            # Ignore shutdown errors and continue with provider initialization
          end

          begin
            # Initialize new provider with timeout
            if provider.respond_to?(:init)
              Timeout.timeout(timeout) do
                provider.init
              end
            end

            # Set the new provider
            new_providers = @providers.dup
            new_providers[domain] = provider
            @providers = new_providers
          rescue Timeout::Error => e
            raise ProviderInitializationError.new(
              "Provider initialization timed out after #{timeout} seconds",
              provider:,
              original_error: e
            )
          rescue StandardError => e
            raise ProviderInitializationError.new(
              "Provider initialization failed: #{e.message}",
              provider:,
              original_error: e
            )
          end
        end
      end
    end
  end
end
