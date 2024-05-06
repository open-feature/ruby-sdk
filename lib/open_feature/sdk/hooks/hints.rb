# frozen_string_literal: true

module OpenFeature
  module SDK
    module Hooks
      class Hints < DelegateClass(Hash)
        ALLOWED_TYPES = [String, Symbol, Numeric, TrueClass, FalseClass, Time, Hash, Array].freeze

        def initialize(hash = {})
          hash.each do |key, value|
            assert_allowed_key(key)
            assert_allowed_value(value)
          end
          @hash = hash.dup
          super(@hash)
          freeze
        end

        private

        def assert_allowed_key(key)
          raise ArgumentError, "Only String or Symbol are allowed as keys." unless key.is_a?(String) || key.is_a?(Symbol)
        end

        def assert_allowed_value(value)
          allowed_type = ALLOWED_TYPES.any? { |t| value.is_a?(t) }
          raise ArgumentError, "Only #{ALLOWED_TYPES.join(", ")} are allowed as values." unless allowed_type
        end
      end
    end
  end
end
