# frozen_string_literal: true

require "forwardable"
require "singleton"

require_relative "configuration"
require_relative "metadata"
require_relative "client"
require_relative "provider/no_op_provider"

module OpenFeature
  module SDK
    # API Initialization and Configuration
    #
    # Represents the entry point to the API, including configuration of <tt>Provider</tt>,<tt>Hook</tt>,
    # and building the <tt>Client</tt>
    #
    # To use the SDK, you can optionally configure a <tt>Provider</tt>, with <tt>Hook</tt>
    #
    #   OpenFeature::SDK.configure do |config|
    #     config.provider = NoOpProvider.new
    #   end
    #
    # If no provider is specified, the <tt>NoOpProvider</tt> is set as the default <tt>Provider</tt>.
    # Once the SDK has been configured, a client can be built
    #
    #   client = OpenFeature::SDK.build_client(name: 'my-open-feature-client')
    class API
      include Singleton
      extend Forwardable

      def_delegator :@configuration, :provider
      def_delegator :@configuration, :hooks
      def_delegator :@configuration, :context

      def configuration
        @configuration ||= Configuration.new
      end

      def configure(&block)
        return unless block_given?

        block.call(configuration)
      end

      def build_client(name: nil, version: nil)
        client_options = Metadata.new(name: name, version: version).freeze
        provider = Provider::NoOpProvider.new if provider.nil?
        Client.new(provider, client_options, context)
      end
    end
  end
end
