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
      PROVIDER_READY = 'PROVIDER_READY'
      PROVIDER_ERROR = 'PROVIDER_ERROR'
      PROVIDER_CONFIGURATION_CHANGED = 'PROVIDER_CONFIGURATION_CHANGED'
      PROVIDER_STALE = 'PROVIDER_STALE'

      ALL_EVENTS = [
        PROVIDER_READY,
        PROVIDER_ERROR,
        PROVIDER_CONFIGURATION_CHANGED,
        PROVIDER_STALE
      ].freeze
    end
  end
end
