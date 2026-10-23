# frozen_string_literal: true

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
        attr_accessor :evaluation_context

        def initialize(flag_key:, flag_value_type:, default_value:, evaluation_context:,
          client_metadata: nil, provider_metadata: nil)
          @flag_key = frozen_copy(flag_key)
          @flag_value_type = flag_value_type.freeze
          @source_default_value = default_value
          @evaluation_context = evaluation_context
          @client_metadata = client_metadata
          @provider_metadata = frozen_copy(provider_metadata)
          @hook_data = {}
          @copies = {}
        end

        # Copied on first read: most hooks never read it, and the copy grows with the value
        def default_value
          @copies.fetch(:default_value) { @copies[:default_value] = frozen_copy(@source_default_value) }
        end

        # Swaps in a frozen copy of the evaluation context, so neither the caller's nor a before hook's object is frozen
        def freeze
          return self if frozen?
          @evaluation_context &&= EvaluationContext.new(**@evaluation_context.fields).freeze
          super
        end

        # Returns a mutable hash scoped to the given hook instance.
        # The same hash is returned across all hook stages (before, after, error, finally),
        # allowing hooks to share state across their lifecycle (spec 4.1.5, 4.6.1).
        def hook_data_for(hook)
          @hook_data[hook.object_id] ||= {}
        end

        private

        # A deep-frozen copy, so hooks can't change it and the caller's object isn't frozen
        def frozen_copy(value)
          Ractor.make_shareable(value, copy: true)
        rescue
          value # shortcut: a value that can't be deep-copied (a Mutex, Queue or Proc inside) stays mutable rather than failing the evaluation
        end
      end
    end
  end
end
