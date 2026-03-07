# frozen_string_literal: true

module OpenFeature
  module SDK
    module Telemetry
      EVENT_NAME = "feature_flag.evaluation"

      FLAG_KEY = "feature_flag.key"
      CONTEXT_ID_KEY = "feature_flag.context.id"
      ERROR_MESSAGE_KEY = "error.message"
      ERROR_TYPE_KEY = "error.type"
      PROVIDER_NAME_KEY = "feature_flag.provider.name"
      RESULT_REASON_KEY = "feature_flag.result.reason"
      RESULT_VALUE_KEY = "feature_flag.result.value"
      RESULT_VARIANT_KEY = "feature_flag.result.variant"
      FLAG_SET_ID_KEY = "feature_flag.set.id"
      VERSION_KEY = "feature_flag.version"

      METADATA_KEY_MAP = {
        "contextId" => CONTEXT_ID_KEY,
        "flagSetId" => FLAG_SET_ID_KEY,
        "version" => VERSION_KEY
      }.freeze

      EvaluationEvent = Struct.new(:name, :attributes, keyword_init: true)

      module_function

      def create_evaluation_event(hook_context:, evaluation_details:)
        attributes = {FLAG_KEY => hook_context.flag_key}

        provider_name = hook_context.provider_metadata&.name
        attributes[PROVIDER_NAME_KEY] = provider_name if provider_name

        targeting_key = hook_context.evaluation_context&.targeting_key
        attributes[CONTEXT_ID_KEY] = targeting_key if targeting_key

        if evaluation_details
          if evaluation_details.variant
            attributes[RESULT_VARIANT_KEY] = evaluation_details.variant
          else
            attributes[RESULT_VALUE_KEY] = evaluation_details.value
          end

          if evaluation_details.reason
            attributes[RESULT_REASON_KEY] = evaluation_details.reason.downcase
          end

          if evaluation_details.error_code
            attributes[ERROR_TYPE_KEY] = evaluation_details.error_code.downcase
          end

          if evaluation_details.error_message
            attributes[ERROR_MESSAGE_KEY] = evaluation_details.error_message
          end

          extract_metadata(evaluation_details.flag_metadata, attributes)
        end

        EvaluationEvent.new(name: EVENT_NAME, attributes: attributes)
      end

      def extract_metadata(flag_metadata, attributes)
        return unless flag_metadata

        METADATA_KEY_MAP.each do |metadata_key, otel_key|
          value = flag_metadata[metadata_key]
          attributes[otel_key] = value unless value.nil?
        end
      end

      private_class_method :extract_metadata
    end
  end
end
