module OpenFeature
  module SDK
    class EvaluationContext
      TARGETING_KEY = "targeting_key"

      attr_reader :fields

      def initialize(**fields)
        @fields = fields.transform_keys(&:to_s)
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
