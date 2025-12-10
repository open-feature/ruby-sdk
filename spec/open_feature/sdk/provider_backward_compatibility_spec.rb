# frozen_string_literal: true

require 'spec_helper'
require 'open_feature/sdk/provider/no_op_provider'
require 'open_feature/sdk/provider/in_memory_provider'
require 'open_feature/sdk/provider/event_aware_no_op_provider'

RSpec.describe 'Provider Backward Compatibility' do
  describe 'Existing NoOpProvider' do
    let(:provider) { OpenFeature::SDK::Provider::NoOpProvider.new }
    
    it 'continues to work without implementing new interfaces' do
      expect { provider.fetch_boolean_value(flag_key: 'test', default_value: true) }.not_to raise_error
    end
    
    it 'does not respond to new interface methods' do
      expect(provider).not_to respond_to(:attach)
      expect(provider).not_to respond_to(:detach)
      expect(provider).not_to respond_to(:emit_event)
    end
    
    it 'does not respond to init or shutdown' do
      expect(provider).not_to respond_to(:init)
      expect(provider).not_to respond_to(:shutdown)
    end
  end
  
  describe 'Existing InMemoryProvider' do
    let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
    
    it 'continues to work with existing init/shutdown methods' do
      expect { provider.init }.not_to raise_error
      expect { provider.shutdown }.not_to raise_error
    end
    
    it 'does not automatically gain event capabilities' do
      expect(provider).not_to respond_to(:attach)
      expect(provider).not_to respond_to(:emit_event)
    end
    
    it 'fetch methods continue to work' do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new(
        'test-flag' => true
      )
      
      result = provider.fetch_boolean_value(flag_key: 'test-flag', default_value: false)
      expect(result.value).to be true
    end
  end
  
  describe 'EventAwareNoOpProvider' do
    let(:provider) { OpenFeature::SDK::Provider::EventAwareNoOpProvider.new }
    
    it 'inherits NoOpProvider functionality' do
      result = provider.fetch_boolean_value(flag_key: 'test', default_value: true)
      expect(result.value).to be true
      expect(result.reason).to eq('No-op')
    end
    
    it 'adds StateHandler capabilities' do
      expect(provider).to respond_to(:init)
      expect(provider).to respond_to(:shutdown)
    end
    
    it 'adds EventHandler capabilities' do
      expect(provider).to respond_to(:attach)
      expect(provider).to respond_to(:detach)
      expect(provider).to respond_to(:emit_event)
    end
    
    it 'emits events when initialized' do
      dispatcher = double('dispatcher')
      provider.attach(dispatcher)
      
      expect(dispatcher).to receive(:dispatch_event).with(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_READY,
        hash_including(message: 'NoOp provider initialized')
      )
      
      provider.init({})
    end
  end
  
  describe 'Mixed provider usage' do
    it 'can use old and new providers together' do
      old_provider = OpenFeature::SDK::Provider::NoOpProvider.new
      new_provider = OpenFeature::SDK::Provider::EventAwareNoOpProvider.new
      
      # Both should work for fetching values
      old_result = old_provider.fetch_string_value(flag_key: 'test', default_value: 'old')
      new_result = new_provider.fetch_string_value(flag_key: 'test', default_value: 'new')
      
      expect(old_result.value).to eq('old')
      expect(new_result.value).to eq('new')
    end
  end
  
  describe 'Provider interface detection' do
    it 'can check if provider implements StateHandler' do
      old_provider = OpenFeature::SDK::Provider::NoOpProvider.new
      new_provider = OpenFeature::SDK::Provider::EventAwareNoOpProvider.new
      
      # Check using respond_to? (Ruby way)
      expect(old_provider.respond_to?(:init)).to be false
      expect(new_provider.respond_to?(:init)).to be true
    end
    
    it 'can check if provider implements EventHandler' do
      old_provider = OpenFeature::SDK::Provider::NoOpProvider.new
      new_provider = OpenFeature::SDK::Provider::EventAwareNoOpProvider.new
      
      # Check using is_a? with module
      expect(old_provider.class.included_modules).not_to include(OpenFeature::SDK::Provider::EventHandler)
      expect(new_provider.class.included_modules).to include(OpenFeature::SDK::Provider::EventHandler)
    end
  end
end