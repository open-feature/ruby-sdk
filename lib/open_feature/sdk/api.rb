# frozen_string_literal: true

require "forwardable"
require "singleton"

require_relative "configuration"
require_relative "evaluation_context"
require_relative "evaluation_context_builder"
require_relative "evaluation_details"
require_relative "client_metadata"
require_relative "client"
require_relative "provider"

module OpenFeature
  module SDK
    # API Initialization and Configuration
    #
    # Represents the entry point to the API, including configuration of <tt>Provider</tt>,<tt>Hook</tt>,
    # and building the <tt>Client</tt>
    #
    # To use the SDK, you can optionally configure a <tt>Provider</tt>, with <tt>Hook</tt>
    #
    #   OpenFeature::SDK::API.instance.configure do |config|
    #     config.set_provider NoOpProvider.new
    #   end
    #
    # If no provider is specified, the <tt>NoOpProvider</tt> is set as the default <tt>Provider</tt>.
    # Once the SDK has been configured, a client can be built
    #
    #   client = OpenFeature::SDK::API.instance.build_client(name: 'my-open-feature-client')
    class API
      include Singleton # Satisfies Flag Evaluation API Requirement 1.1.1
      extend Forwardable

      def_delegators :configuration, :provider, :set_provider, :hooks, :evaluation_context

      def configuration
        @configuration ||= Configuration.new
      end

      def configure(&block)
        return unless block

        block.call(configuration)
      end

      def build_client(domain: nil, evaluation_context: nil)
        active_provider = provider(domain:).nil? ? Provider::NoOpProvider.new : provider(domain:)

        Client.new(provider: active_provider, domain:, evaluation_context:)
      rescue
        Client.new(provider: Provider::NoOpProvider.new, evaluation_context:)
      end
    end
  end
end
