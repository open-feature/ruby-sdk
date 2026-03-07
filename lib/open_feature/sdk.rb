# frozen_string_literal: true

require_relative "sdk/version"
require_relative "sdk/api"
require_relative "sdk/telemetry"
require_relative "sdk/transaction_context_propagator"
require_relative "sdk/thread_local_transaction_context_propagator"

module OpenFeature
  # TODO: Add documentation
  #
  module SDK
    class << self
      def method_missing(method_name, ...)
        if API.instance.respond_to?(method_name)
          API.instance.send(method_name, ...)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        API.instance.respond_to?(method_name, include_private) || super
      end
    end
  end
end
