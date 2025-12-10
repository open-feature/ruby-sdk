# frozen_string_literal: true

module OpenFeature
  module SDK
    # Provider Event Types
    #
    # Defines the standard event types that providers can emit during their lifecycle.
    # These events correspond to the OpenFeature specification events:
    # https://openfeature.dev/specification/sections/events/
    #
    module ProviderEvent
      # Emitted when provider initialization completes successfully
      PROVIDER_READY = 'PROVIDER_READY'

      # Emitted when provider initialization fails
      PROVIDER_ERROR = 'PROVIDER_ERROR'

      # Emitted when provider configuration changes
      PROVIDER_CONFIGURATION_CHANGED = 'PROVIDER_CONFIGURATION_CHANGED'

      # Emitted when provider enters a stale state
      PROVIDER_STALE = 'PROVIDER_STALE'

      # All supported event types for validation
      ALL_EVENTS = [
        PROVIDER_READY,
        PROVIDER_ERROR,
        PROVIDER_CONFIGURATION_CHANGED,
        PROVIDER_STALE
      ].freeze
    end
  end
end
