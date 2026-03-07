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
    end
  end
end
