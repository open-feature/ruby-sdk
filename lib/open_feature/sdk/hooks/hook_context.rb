# frozen_string_literal: true

module OpenFeature
  module SDK
    module Hooks
      # Provides context to hook stages during flag evaluation.
      #
      # Per spec 4.1.1-4.1.5:
      # - flag_key, flag_value_type, default_value are immutable (4.1.3)
      # - client_metadata, provider_metadata are optional (4.1.2)
      # - evaluation_context is mutable (for before hooks to modify, 4.1.4.1)
      class HookContext
        attr_reader :flag_key, :flag_value_type, :default_value,
          :client_metadata, :provider_metadata
        attr_accessor :evaluation_context

        def initialize(flag_key:, flag_value_type:, default_value:, evaluation_context:,
          client_metadata: nil, provider_metadata: nil)
          @flag_key = flag_key.freeze
          @flag_value_type = flag_value_type.freeze
          @default_value = default_value
          @evaluation_context = evaluation_context
          @client_metadata = client_metadata
          @provider_metadata = provider_metadata
        end
      end
    end
  end
end
