module OpenFeature
  module SDK
    class EvaluationContext
      attr_reader :targeting_key

      def initialize(targeting_key: nil)
        @targeting_key = targeting_key
      end
    end
  end
end
