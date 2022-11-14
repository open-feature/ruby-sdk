# frozen_string_literal: true

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Client
      attr_reader :metadata

      attr_accessor :hooks

      def initialize(provider, client_options, context)
        @provider = provider
        @client_options = client_options
        @context = context
      end
    end
  end
end
