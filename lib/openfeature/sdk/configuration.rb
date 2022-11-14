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

      attr_accessor :context, :provider, :hooks

      def_delegator :@provider, :metadata

      def initialize
        @hooks = Concurrent::Array.new([])
      end
    end
  end
end
