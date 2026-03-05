# frozen_string_literal: true

module OpenFeature
  module SDK
    # Represents tracking event details per spec section 6.2.
    #
    # Requirement 6.2.1: MUST define an optional numeric value.
    # Requirement 6.2.2: MUST support custom fields (string keys,
    # boolean/string/number/structure values).
    class TrackingEventDetails
      attr_reader :value, :fields

      def initialize(value: nil, **fields)
        if !value.nil? && !value.is_a?(Numeric)
          raise ArgumentError, "Tracking event value must be Numeric, got #{value.class}"
        end

        @value = value
        @fields = fields.transform_keys(&:to_s)
      end
    end
  end
end
