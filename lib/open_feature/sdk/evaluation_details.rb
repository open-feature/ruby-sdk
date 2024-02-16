module OpenFeature
  module SDK
    EvaluationDetails = Struct.new(:flag_key, :resolution_details) do
      extend Forwardable

      def_delegators :resolution_details, :value, :reason, :variant, :error_code, :error_message, :flag_metadata
    end
  end
end
