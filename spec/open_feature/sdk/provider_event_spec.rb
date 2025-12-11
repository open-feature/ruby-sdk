# frozen_string_literal: true

require 'spec_helper'
require 'open_feature/sdk/provider_event'

RSpec.describe OpenFeature::SDK::ProviderEvent do
  it 'defines PROVIDER_READY constant' do
    expect(described_class::PROVIDER_READY).to eq('PROVIDER_READY')
  end

  it 'defines PROVIDER_ERROR constant' do
    expect(described_class::PROVIDER_ERROR).to eq('PROVIDER_ERROR')
  end

  it 'defines PROVIDER_CONFIGURATION_CHANGED constant' do
    expect(described_class::PROVIDER_CONFIGURATION_CHANGED).to eq('PROVIDER_CONFIGURATION_CHANGED')
  end

  it 'defines PROVIDER_STALE constant' do
    expect(described_class::PROVIDER_STALE).to eq('PROVIDER_STALE')
  end

  it 'defines ALL_EVENTS with all event types' do
    expect(described_class::ALL_EVENTS).to contain_exactly(
      'PROVIDER_READY',
      'PROVIDER_ERROR',
      'PROVIDER_CONFIGURATION_CHANGED',
      'PROVIDER_STALE'
    )
  end

  it 'has frozen ALL_EVENTS array' do
    expect(described_class::ALL_EVENTS).to be_frozen
  end
end
