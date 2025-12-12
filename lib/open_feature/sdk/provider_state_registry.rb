# frozen_string_literal: true

require_relative "provider_state"
require_relative "provider_event"
require_relative "event_to_state_mapper"

module OpenFeature
  module SDK
    # Tracks provider states
    class ProviderStateRegistry
      def initialize
        @states = {}
        @mutex = Mutex.new
      end

      def set_initial_state(provider, state = ProviderState::NOT_READY)
        return unless provider

        @mutex.synchronize do
          @states[provider.object_id] = state
        end
      end

      def update_state_from_event(provider, event_type, event_details = nil)
        return ProviderState::NOT_READY unless provider

        new_state = EventToStateMapper.state_from_event(event_type, event_details)

        @mutex.synchronize do
          @states[provider.object_id] = new_state
        end

        new_state
      end

      def get_state(provider)
        return ProviderState::NOT_READY unless provider

        @mutex.synchronize do
          @states[provider.object_id] || ProviderState::NOT_READY
        end
      end

      def remove_provider(provider)
        return unless provider

        @mutex.synchronize do
          @states.delete(provider.object_id)
        end
      end

      def ready?(provider)
        get_state(provider) == ProviderState::READY
      end

      def error?(provider)
        state = get_state(provider)
        [ProviderState::ERROR, ProviderState::FATAL].include?(state)
      end

      def clear
        @mutex.synchronize do
          @states.clear
        end
      end
    end
  end
end
