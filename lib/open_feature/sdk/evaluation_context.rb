module OpenFeature
  module SDK
    class EvaluationContext
      TARGETING_KEY = "targeting_key"

      attr_reader :fields

      def initialize(targeting_key: nil, **fields)
        fields = fields.merge({TARGETING_KEY => targeting_key}).merge(fields) if targeting_key

        @fields = fields
      end

      def targeting_key
        fields[TARGETING_KEY]
      end

      def field(key)
        fields[key]
      end

      def merge(overriding_context)
        EvaluationContext.new(
          targeting_key: overriding_context.targeting_key || targeting_key,
          **fields.merge(overriding_context.fields)
        )
      end

      def ==(other)
        fields == other.fields
      end
    end
  end
end
