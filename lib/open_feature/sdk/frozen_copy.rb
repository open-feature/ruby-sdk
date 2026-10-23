# frozen_string_literal: true

module OpenFeature
  module SDK
    # Deep-frozen copies of the spec's value types (spec 3.1.2), so whoever gets one can't change it and the original is
    # never frozen (spec 1.4.15.1, 4.1.3, 4.1.4.1, 4.2.2)
    module FrozenCopy
      def self.of(value, seen = nil)
        return value if Ractor.shareable?(value)

        case value
        when String, Time then value.dup.freeze # Time#localtime and #utc change the receiver
        when Hash, Array
          seen ||= {}.compare_by_identity
          return seen[value] if seen.key?(value)

          # Registered before its items, so a cycle or a shared structure maps to this one copy
          copy = seen[value] = value.dup
          value.is_a?(Hash) ? copy.transform_values! { |item| of(item, seen) } : copy.map! { |item| of(item, seen) }
          copy.freeze
        else
          value # Anything else, like a user object or a record, is passed through as is
        end
      end
    end
  end
end
