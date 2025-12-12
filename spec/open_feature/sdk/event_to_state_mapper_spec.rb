# frozen_string_literal: true

require 'spec_helper'
require 'open_feature/sdk/event_to_state_mapper'
require 'open_feature/sdk/provider_event'
require 'open_feature/sdk/provider_state'

RSpec.describe OpenFeature::SDK::EventToStateMapper do
  describe '.state_from_event' do
    context 'with PROVIDER_READY event' do
      it 'returns READY state' do
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        expect(state).to eq(OpenFeature::SDK::ProviderState::READY)
      end
    end

    context 'with PROVIDER_CONFIGURATION_CHANGED event' do
      it 'returns READY state' do
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED)
        expect(state).to eq(OpenFeature::SDK::ProviderState::READY)
      end
    end

    context 'with PROVIDER_STALE event' do
      it 'returns STALE state' do
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)
        expect(state).to eq(OpenFeature::SDK::ProviderState::STALE)
      end
    end

    context 'with PROVIDER_ERROR event' do
      it 'returns ERROR state by default' do
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR)
        expect(state).to eq(OpenFeature::SDK::ProviderState::ERROR)
      end

      it 'returns ERROR state for non-fatal error' do
        event_details = {
          message: 'Connection failed',
          error_code: 'CONNECTION_ERROR'
        }
        
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, event_details)
        expect(state).to eq(OpenFeature::SDK::ProviderState::ERROR)
      end

      it 'returns FATAL state for fatal error' do
        event_details = {
          message: 'Provider cannot recover',
          error_code: OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL
        }
        
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, event_details)
        expect(state).to eq(OpenFeature::SDK::ProviderState::FATAL)
      end

      it 'handles Hash event details' do
        event_details_hash = {
          message: 'Provider cannot recover',
          error_code: OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL
        }
        
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, event_details_hash)
        expect(state).to eq(OpenFeature::SDK::ProviderState::FATAL)
      end


      it 'handles nil event details gracefully' do
        state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, nil)
        expect(state).to eq(OpenFeature::SDK::ProviderState::ERROR)
      end
    end

    context 'with unknown event type' do
      it 'returns NOT_READY state as fallback' do
        state = described_class.state_from_event('UNKNOWN_EVENT')
        expect(state).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
      end
    end
  end



  describe 'integration with ProviderEvent and ProviderState constants' do
    it 'handles all valid provider events' do
      OpenFeature::SDK::ProviderEvent::ALL_EVENTS.each do |event_type|
        expect do
          described_class.state_from_event(event_type)
        end.not_to raise_error
      end
    end

    it 'maps to valid provider states' do
      # Test all known events return valid states
      ready_state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
      config_state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED)
      stale_state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)
      error_state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR)
      fatal_state = described_class.state_from_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, { error_code: OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL })
      
      expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(ready_state)
      expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(config_state)
      expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(stale_state)
      expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(error_state)
      expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(fatal_state)
    end
  end
end
