module OpenFeature
  module SDK
    module Provider
      # TODO: Add evaluation context support
      class InMemoryProvider
        NAME = "In-memory Provider"

        attr_reader :metadata

        def initialize(flags = {})
          @metadata = ProviderMetadata.new(name: NAME).freeze
          @flags = flags
        end

        def init
          # Intentional no-op, used for testing
        end

        def shutdown
          # Intentional no-op, used for testing
        end

        def add_flag(flag_key:, value:)
          flags[flag_key] = value
          # TODO: Emit PROVIDER_CONFIGURATION_CHANGED event once events are implemented
        end

        def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(allowed_classes: [TrueClass, FalseClass], flag_key:, default_value:, evaluation_context:)
        end

        def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(allowed_classes: [String], flag_key:, default_value:, evaluation_context:)
        end

        def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(allowed_classes: [Integer, Float], flag_key:, default_value:, evaluation_context:)
        end

        def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
          fetch_value(allowed_classes: [Array, Hash], flag_key:, default_value:, evaluation_context:)
        end

        private

        attr_reader :flags

        def fetch_value(allowed_classes:, flag_key:, default_value:, evaluation_context:)
          value = flags[flag_key]

          if value.nil?
            return ResolutionDetails.new(value: default_value, error_code: ErrorCode::FLAG_NOT_FOUND, reason: Reason::ERROR)
          end

          if allowed_classes.include?(value.class)
            ResolutionDetails.new(value:, reason: Reason::STATIC)
          else
            ResolutionDetails.new(value: default_value, error_code: ErrorCode::TYPE_MISMATCH, reason: Reason::ERROR)
          end
        end
      end
    end
  end
end
