# frozen_string_literal: true

module OpenFeature
  module SDK
    module Provider
      class InMemoryProvider
        include Provider::EventEmitter

        NAME = "In-memory Provider"

        attr_reader :metadata

        def initialize(flags = {})
          @metadata = ProviderMetadata.new(name: NAME).freeze
          @flags = flags
        end

        def init(evaluation_context = nil)
          # Intentional no-op, used for testing
        end

        def shutdown
          # Intentional no-op, used for testing
        end

        def add_flag(flag_key:, value:)
          flags[flag_key] = value
          emit_provider_changed([flag_key])
        end

        def update_flags(new_flags)
          @flags = new_flags.dup
          emit_provider_changed(new_flags.keys)
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

          if raw_value.respond_to?(:call)
            value = raw_value.call(evaluation_context)
            ResolutionDetails.new(value: value, reason: Reason::TARGETING_MATCH)
          else
            ResolutionDetails.new(value: raw_value, reason: Reason::STATIC)
          end
        end

        def emit_provider_changed(flag_keys)
          return unless configuration_attached?

          emit_event(ProviderEvent::PROVIDER_CONFIGURATION_CHANGED, flags_changed: flag_keys)
        end
      end
    end
  end
end
