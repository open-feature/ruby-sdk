# frozen_string_literal: true

module OpenFeature
  module SDK
    module Provider
      module Reason
        STATIC = "STATIC"
        DEFAULT = "DEFAULT"
        TARGETING_MATCH = "TARGETING_MATCH"
        TARGETING_MATCH_SPLIT = "TARGETING_MATCH_SPLIT"
        SPLIT = "SPLIT"
        CACHED = "CACHED"
        DISABLED = "DISABLED"
        UNKNOWN = "UNKNOWN"
        STALE = "STALE"
        ERROR = "ERROR"
      end
    end
  end
end
