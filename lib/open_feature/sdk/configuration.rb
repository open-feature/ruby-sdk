# frozen_string_literal: true

require "concurrent"

require_relative "api"

module OpenFeature
  module SDK
    # Represents the configuration object for the global API where <tt>Provider</tt>, <tt>Hook</tt>,
    # and <tt>Context</tt> are configured.
    # This class is not meant to be interacted with directly but instead through the <tt>OpenFeature::SDK.configure</tt>
    # method
    class Configuration
      extend Forwardable

      attr_accessor :context, :hooks
      attr_reader :provider

      def_delegator :@provider, :metadata

      def initialize
        @hooks = []
      end

      # When switching providers, there are a few lifecycle methods that need to be taken care of.
      #   1. If a provider is already set, we need to call `shutdown` on it.
      #   2. On the new provider, call `init`.
      #   3. Finally, set the internal provider to the new provider
      def provider=(provider)
        @provider.shutdown if !@provider.nil? && @provider.respond_to?(:shutdown)

        provider.init if provider.respond_to?(:init)

        @provider = provider
      end
    end
  end
end
