# typed: true
# frozen_string_literal: true

require_relative("../metadata")
require_relative("../evaluation_context")

module OpenFeature
  module SDK
    module Hook
      class HookContext < T::Struct
        const :flag_key, String
        const :default_value, T.any(T::Boolean, String, Integer, Integer, Float)
        const :flag_value_type, T.any(String, Integer, Float, TrueClass, FalseClass)
        const :context, T.nilable(EvaluationContext)
        const :client_metadata, SDK::Metadata
        const :provider_metadata, SDK::Metadata
        const :logger, T.nilable(T.untyped)
      end
    end
  end
end
