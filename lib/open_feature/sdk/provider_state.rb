# frozen_string_literal: true

module OpenFeature
  module SDK
    # Provider State Types
    #
    # Defines the standard states that providers can be in during their lifecycle.
    # These states correspond to the OpenFeature specification provider states:
    # https://openfeature.dev/specification/types#provider-status
    #
    module ProviderState
      NOT_READY = 'NOT_READY'
      READY = 'READY'
      ERROR = 'ERROR'
      STALE = 'STALE'
      FATAL = 'FATAL'

      ALL_STATES = [
        NOT_READY,
        READY,
        ERROR,
        STALE,
        FATAL
      ].freeze
    end
  end
end
