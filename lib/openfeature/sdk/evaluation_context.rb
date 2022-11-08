# frozen_string_literal: true
# typed: true

# frozen_literal: true

require "sorbet-runtime"
require "date"

class EvaluationContext < T::Struct
  CustomFieldValues = T.type_alias { T.any(T::Boolean, String, Integer, Float, T.untyped, DateTime) }
  CustomField = T.type_alias { T::Hash[String, CustomFieldValues] }

  const :targeting_key, T.nilable(String)
  const :custom_fields, T.nilable(CustomField)
end
