# frozen_string_literal: true

module OpenFeature
  module SDK
    module Provider
      class InMemoryProvider
        include Provider::EventEmitter

        NAME = "In-memory Provider"

        # A flag with named variants. +context_evaluator+ receives the evaluation
        # context and returns a variant key; anything else falls back to +default_variant+.
        Flag = Struct.new(:variants, :default_variant, :context_evaluator, :flag_metadata, :disabled, keyword_init: true)

        attr_reader :metadata

        def initialize(flags = {})
          @metadata = ProviderMetadata.new(name: NAME).freeze
          @flags = flags
        end

        def shutdown
          # Intentional no-op, used for testing
        end

        def add_flag(flag_key:, value:)
          flags[flag_key] = value
          emit_provider_changed([flag_key])
        end

        def update_flags(new_flags)
          old_keys = @flags.keys
          @flags = new_flags.dup
          changed_keys = (old_keys | new_flags.keys)
          emit_provider_changed(changed_keys)
        end

        def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(flag_key:, default_value:, evaluation_context:)
        end

        def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(flag_key:, default_value:, evaluation_context:)
        end

        def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(flag_key:, default_value:, evaluation_context:)
        end

        def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(flag_key:, default_value:, evaluation_context:)
        end

        def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(flag_key:, default_value:, evaluation_context:)
        end

        def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(flag_key:, default_value:, evaluation_context:)
        end

        private

        attr_reader :flags

        def fetch_value(flag_key:, default_value:, evaluation_context:)
          raw_value = flags[flag_key]

          if raw_value.nil?
            return ResolutionDetails.new(value: default_value, error_code: ErrorCode::FLAG_NOT_FOUND, reason: Reason::ERROR)
          end

          return resolve_variant_flag(raw_value, default_value, evaluation_context) if raw_value.is_a?(Flag)

          if raw_value.respond_to?(:call)
            value = raw_value.call(evaluation_context)
            ResolutionDetails.new(value: value, reason: Reason::TARGETING_MATCH)
          else
            ResolutionDetails.new(value: raw_value, reason: Reason::STATIC)
          end
        end

        def resolve_variant_flag(flag, default_value, evaluation_context)
          flag_metadata = flag.flag_metadata
          return ResolutionDetails.new(value: default_value, reason: Reason::DISABLED, flag_metadata:) if flag.disabled

          variants = flag.variants.to_h
          unless variants.key?(flag.default_variant)
            return ResolutionDetails.new(value: default_value, error_code: ErrorCode::PARSE_ERROR, reason: Reason::ERROR, flag_metadata:)
          end

          matched = flag.context_evaluator&.call(evaluation_context)
          if variants.key?(matched)
            return ResolutionDetails.new(value: variants[matched], variant: matched, reason: Reason::TARGETING_MATCH, flag_metadata:)
          end

          reason = flag.context_evaluator ? Reason::DEFAULT : Reason::STATIC
          ResolutionDetails.new(value: variants[flag.default_variant], variant: flag.default_variant, reason:, flag_metadata:)
        end

        def emit_provider_changed(flag_keys)
          return unless configuration_attached?

          emit_event(ProviderEvent::PROVIDER_CONFIGURATION_CHANGED, flags_changed: flag_keys)
        end
      end
    end
  end
end
