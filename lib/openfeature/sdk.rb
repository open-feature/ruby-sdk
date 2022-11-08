# frozen_string_literal: true

require "sorbet-runtime"
require "forwardable"

require_relative "sdk/version"
require_relative "sdk/configuration"
require_relative "sdk/client"
require_relative "sdk/metadata"
require_relative "sdk/provider/no_op_provider"

module OpenFeature
  # API Initialization and Configuration
  #
  # Represents the entry point to the SDK, including configuration of <tt>Provider</tt>,<tt>Hook</tt>,
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
  module SDK
    class << self
      extend T::Sig
      extend Forwardable

      def_delegator :@configuration, :provider
      def_delegator :@configuration, :hooks
      def_delegator :@configuration, :context

      sig { returns(Configuration) }
      def configuration
        @configuration ||= T.let(Configuration.new, Configuration)
      end

      # rubocop:disable Lint/UnusedMethodArgument
      sig { params(block: T.proc.params(arg0: Configuration).void).void }
      def configure(&block)
        return unless block_given?

        yield(configuration)
      end
      # rubocop:enable Lint/UnusedMethodArgument

      sig do
        params(
          name: T.nilable(String),
          version: T.nilable(String),
          context: T.nilable(EvaluationContext)
        ).returns(SDK::Client)
      end
      def build_client(name: nil, version: nil, context: nil)
        client_options = Metadata.new(name: name, version: version)
        provider = Provider::NoOpProvider.new if provider.nil?
        SDK::Client.new(provider, client_options, context)
      end
    end
  end
end
