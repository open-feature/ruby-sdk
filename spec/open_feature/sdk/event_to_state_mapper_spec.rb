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



  describe 'STATE_MAPPING constant' do
    it 'is frozen to prevent modification' do
      expect(described_class::STATE_MAPPING).to be_frozen
    end

    it 'contains mappings for all provider events' do
      expected_events = [
        OpenFeature::SDK::ProviderEvent::PROVIDER_READY,
        OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED,
        OpenFeature::SDK::ProviderEvent::PROVIDER_STALE,
        OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR
      ]
      
      expect(described_class::STATE_MAPPING.keys).to contain_exactly(*expected_events)
    end
  end

  describe 'integration with ProviderEvent and ProviderState constants' do
    it 'uses valid provider events' do
      described_class::STATE_MAPPING.keys.each do |event_type|
        expect(OpenFeature::SDK::ProviderEvent::ALL_EVENTS).to include(event_type)
      end
    end

    it 'maps to valid provider states' do
      # Test non-callable mappings
      non_callable_mappings = described_class::STATE_MAPPING.reject { |k, v| v.respond_to?(:call) }
      non_callable_mappings.values.each do |state|
        expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(state)
      end

      # Test callable mappings (PROVIDER_ERROR)
      error_mapper = described_class::STATE_MAPPING[OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR]
      fatal_state = error_mapper.call({ error_code: 'PROVIDER_FATAL' })
      error_state = error_mapper.call({ error_code: 'SOME_ERROR' })
      
      expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(fatal_state)
      expect(OpenFeature::SDK::ProviderState::ALL_STATES).to include(error_state)
    end
  end
end
