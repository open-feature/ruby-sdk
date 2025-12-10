# frozen_string_literal: true

module OpenFeature
  module SDK
    # Provider State Types
    #
    # Defines the standard states that providers can be in during their lifecycle.
    # These states correspond to the OpenFeature specification provider states.
    #
    module ProviderState
      # Provider is not ready to serve flag evaluations
      NOT_READY = 'NOT_READY'

      # Provider is ready to serve flag evaluations
      READY = 'READY'

      # Provider encountered an error but may recover
      ERROR = 'ERROR'

      # Provider data is stale and should be refreshed
      STALE = 'STALE'

      # Provider encountered a fatal error and cannot recover
      FATAL = 'FATAL'

      # All supported provider states for validation
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
