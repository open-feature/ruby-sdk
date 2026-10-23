# frozen_string_literal: true

require_relative "../frozen_copy"

module OpenFeature
  module SDK
    module Hooks
      # Provides context to hook stages during flag evaluation.
      #
      # Per spec 4.1.1-4.1.5 and 4.2.2:
      # - flag_key, flag_value_type, default_value are immutable (4.1.3)
      # - client_metadata, provider_metadata are optional (4.1.2) and immutable (4.2.2.2, 4.2.2.3)
      # - evaluation_context is mutable only in before hooks; HookExecutor freezes the hook context after them (4.1.4.1)
      class HookContext
        attr_reader :flag_key, :flag_value_type, :client_metadata, :provider_metadata
        attr_writer :evaluation_context

        def initialize(flag_key:, flag_value_type:, default_value:, evaluation_context:,
          client_metadata: nil, provider_metadata: nil)
          @flag_key = FrozenCopy.of(flag_key)
          @flag_value_type = flag_value_type.freeze
          @source_default_value = default_value
          @evaluation_context = evaluation_context
          @client_metadata = client_metadata
          @provider_metadata = frozen_metadata(provider_metadata)
          @hook_data = {}
          @copies = {}
        end

        # Copied on first read: most hooks never read it, and the copy grows with the value
        def default_value
          @copies.fetch(:default_value) { @copies[:default_value] = FrozenCopy.of(@source_default_value) }
        end

        # Live during the before stage; once frozen, a deep-frozen copy made on first read, so neither the caller's
        # context nor one a before hook assigned is frozen
        def evaluation_context
          return @evaluation_context unless frozen?

          @copies.fetch(:evaluation_context) do
            @copies[:evaluation_context] = @evaluation_context&.dup&.tap do |copy|
              seen = {}.compare_by_identity # One map for every field, so a structure two fields share is copied once
              copy.fields.transform_values! { |value| FrozenCopy.of(value, seen) }
            end&.freeze
          end
        end

        # Returns a mutable hash scoped to the given hook instance.
        # The same hash is returned across all hook stages (before, after, error, finally),
        # allowing hooks to share state across their lifecycle (spec 4.1.5, 4.6.1).
        def hook_data_for(hook)
          @hook_data[hook.object_id] ||= {}
        end

        private

        # FrozenCopy passes Structs through, so ProviderMetadata's members are copied here (spec 4.2.2.3)
        def frozen_metadata(metadata)
          return metadata if !metadata.is_a?(Struct) || (defined?(Ractor) && Ractor.shareable?(metadata))

          metadata.dup.tap { |copy| copy.each_pair { |member, value| copy[member] = FrozenCopy.of(value) } }.freeze
        end
      end
    end
  end
end
