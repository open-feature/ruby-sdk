# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require_relative("./resolution_details")

class EvaluationDetails < ResolutionDetails
  const :flag_key, String
end
