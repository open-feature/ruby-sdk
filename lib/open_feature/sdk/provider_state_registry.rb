# frozen_string_literal: true

require_relative 'provider_state'
require_relative 'provider_event'
require_relative 'event_to_state_mapper'

module OpenFeature
  module SDK
    # ProviderStateRegistry tracks the state of registered providers.
    #
    # The registry maintains:
    # - Current state for each provider
    # - Thread-safe state transitions
    # - State queries for providers
    class ProviderStateRegistry
      def initialize
        @states = {}
        @mutex = Mutex.new
      end

      # Set initial state for a provider
      #
      # @param provider [Object] the provider instance
      # @param state [String] the initial state (default: NOT_READY)
      def set_initial_state(provider, state = ProviderState::NOT_READY)
        @mutex.synchronize do
          @states[provider.object_id] = state
        end
      end

      # Update provider state based on an event
      #
      # @param provider [Object] the provider instance
      # @param event_type [String] the event that occurred
      # @param event_details [Hash] optional event details
      def update_state_from_event(provider, event_type, event_details = nil)
        new_state = EventToStateMapper.state_from_event(event_type, event_details)
        
        @mutex.synchronize do
          @states[provider.object_id] = new_state
        end
        
        new_state
      end

      # Get the current state of a provider
      #
      # @param provider [Object] the provider instance
      # @return [String] the current state or NOT_READY if not tracked
      def get_state(provider)
        @mutex.synchronize do
          @states[provider.object_id] || ProviderState::NOT_READY
        end
      end

      # Remove a provider from state tracking
      #
      # @param provider [Object] the provider instance
      def remove_provider(provider)
        @mutex.synchronize do
          @states.delete(provider.object_id)
        end
      end

      # Check if a provider is ready
      #
      # @param provider [Object] the provider instance
      # @return [Boolean] true if provider is in READY state
      def ready?(provider)
        get_state(provider) == ProviderState::READY
      end

      # Check if a provider is in an error state
      #
      # @param provider [Object] the provider instance
      # @return [Boolean] true if provider is in ERROR or FATAL state
      def error?(provider)
        state = get_state(provider)
        state == ProviderState::ERROR || state == ProviderState::FATAL
      end

      # Clear all provider states
      def clear
        @mutex.synchronize do
          @states.clear
        end
      end
    end
  end
end