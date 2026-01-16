# frozen_string_literal: true

require "spec_helper"
require "open_feature/sdk/provider_state_registry"
require "open_feature/sdk/provider_state"
require "open_feature/sdk/provider_event"

RSpec.describe OpenFeature::SDK::ProviderStateRegistry do
  let(:registry) { described_class.new }
  let(:provider) { double("Provider", object_id: 12_345) }
  let(:provider2) { double("Provider2", object_id: 67_890) }

  describe "#set_initial_state" do
    it "sets NOT_READY as default state" do
      registry.set_initial_state(provider)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
    end

    it "sets custom initial state" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::READY)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end
  end

  describe "#update_state_from_event" do
    before do
      registry.set_initial_state(provider)
    end

    it "updates state to READY on PROVIDER_READY event" do
      new_state = registry.update_state_from_event(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_READY
      )

      expect(new_state).to eq(OpenFeature::SDK::ProviderState::READY)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end

    it "updates state to ERROR on PROVIDER_ERROR event" do
      new_state = registry.update_state_from_event(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR
      )

      expect(new_state).to eq(OpenFeature::SDK::ProviderState::ERROR)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::ERROR)
    end

    it "updates state to FATAL on PROVIDER_ERROR with fatal error code" do
      new_state = registry.update_state_from_event(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR,
        {error_code: OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL}
      )

      expect(new_state).to eq(OpenFeature::SDK::ProviderState::FATAL)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::FATAL)
    end

    it "updates state to STALE on PROVIDER_STALE event" do
      new_state = registry.update_state_from_event(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_STALE
      )

      expect(new_state).to eq(OpenFeature::SDK::ProviderState::STALE)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::STALE)
    end

    it "does not change state on PROVIDER_CONFIGURATION_CHANGED event" do
      # Set provider to READY state first
      registry.update_state_from_event(provider, OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)

      # PROVIDER_CONFIGURATION_CHANGED should not change the state
      new_state = registry.update_state_from_event(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED
      )

      expect(new_state).to eq(OpenFeature::SDK::ProviderState::READY)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end

    it "does not change state for unknown events" do
      # Set provider to READY state first
      registry.update_state_from_event(provider, OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)

      # Unknown event should not change the state
      new_state = registry.update_state_from_event(provider, "UNKNOWN_EVENT")

      expect(new_state).to eq(OpenFeature::SDK::ProviderState::READY)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end
  end

  describe "#get_state" do
    it "returns NOT_READY for untracked provider" do
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
    end

    it "returns the current state for tracked provider" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::READY)
      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end
  end

  describe "#remove_provider" do
    it "removes provider from tracking" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::READY)
      registry.remove_provider(provider)

      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
    end

    it "handles nil provider gracefully" do
      expect { registry.remove_provider(nil) }.not_to raise_error
    end
  end

  describe "nil provider handling" do
    it "set_initial_state handles nil provider gracefully" do
      expect { registry.set_initial_state(nil) }.not_to raise_error
    end

    it "update_state_from_event handles nil provider gracefully" do
      result = registry.update_state_from_event(nil, OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
      expect(result).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
    end

    it "get_state handles nil provider gracefully" do
      state = registry.get_state(nil)
      expect(state).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
    end

    it "ready? handles nil provider gracefully" do
      expect(registry.ready?(nil)).to be false
    end

    it "error? handles nil provider gracefully" do
      expect(registry.error?(nil)).to be false
    end
  end

  describe "#ready?" do
    it "returns true when provider is READY" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::READY)
      expect(registry.ready?(provider)).to be true
    end

    it "returns false when provider is not READY" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::ERROR)
      expect(registry.ready?(provider)).to be false
    end

    it "returns false for untracked provider" do
      expect(registry.ready?(provider)).to be false
    end
  end

  describe "#error?" do
    it "returns true when provider is in ERROR state" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::ERROR)
      expect(registry.error?(provider)).to be true
    end

    it "returns true when provider is in FATAL state" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::FATAL)
      expect(registry.error?(provider)).to be true
    end

    it "returns false when provider is READY" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::READY)
      expect(registry.error?(provider)).to be false
    end

    it "returns false for untracked provider" do
      expect(registry.error?(provider)).to be false
    end
  end

  describe "#clear" do
    it "removes all provider states" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::READY)
      registry.set_initial_state(provider2, OpenFeature::SDK::ProviderState::ERROR)

      registry.clear

      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
      expect(registry.get_state(provider2)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
    end
  end

  describe "thread safety" do
    it "handles concurrent state updates" do
      threads = []

      # Start provider as NOT_READY
      registry.set_initial_state(provider)

      # Concurrent updates
      10.times do |i|
        threads << Thread.new do
          if i.even?
            registry.update_state_from_event(provider, OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
          else
            registry.update_state_from_event(provider, OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR)
          end
        end
      end

      threads.each(&:join)

      # Should be in one of the valid states
      final_state = registry.get_state(provider)
      expect([
        OpenFeature::SDK::ProviderState::READY,
        OpenFeature::SDK::ProviderState::ERROR
      ]).to include(final_state)
    end
  end

  describe "multiple providers" do
    it "tracks states independently" do
      registry.set_initial_state(provider, OpenFeature::SDK::ProviderState::READY)
      registry.set_initial_state(provider2, OpenFeature::SDK::ProviderState::ERROR)

      expect(registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
      expect(registry.get_state(provider2)).to eq(OpenFeature::SDK::ProviderState::ERROR)

      expect(registry.ready?(provider)).to be true
      expect(registry.ready?(provider2)).to be false

      expect(registry.error?(provider)).to be false
      expect(registry.error?(provider2)).to be true
    end
  end

  describe "event handling" do
    it "handles all valid provider events without errors" do
      OpenFeature::SDK::ProviderEvent::ALL_EVENTS.each do |event_type|
        expect do
          registry.update_state_from_event(provider, event_type)
        end.not_to raise_error
      end
    end
  end
end
