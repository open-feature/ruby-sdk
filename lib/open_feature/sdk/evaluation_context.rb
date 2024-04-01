module OpenFeature
  module SDK
    class EvaluationContext
      TARGETING_KEY = "targeting_key"

      attr_reader :fields

      def initialize(targeting_key: nil, **fields)
        @fields = {TARGETING_KEY => targeting_key}.merge(fields)
      end

      def targeting_key
        fields[TARGETING_KEY]
      end
    end
  end
end
