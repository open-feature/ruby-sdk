# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require_relative("./resolution_details")

class ResolutionReason < T::Enum
  enums do
    DEFAULT = new("DEFAULT")
    TARGETING_MATCH = new("TARGETING_MATCH")
    SPLIT = new("SPLIT")
    DISABLED = new("DISABLED")
    UNKNOWN = new("UNKNOWN")
    ERROR = new("ERROR")
  end
end
