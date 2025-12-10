# frozen_string_literal: true

require 'spec_helper'
require 'open_feature/sdk/provider/state_handler'

RSpec.describe OpenFeature::SDK::Provider::StateHandler do
  let(:test_class) do
    Class.new do
      include OpenFeature::SDK::Provider::StateHandler
      
      attr_reader :initialized, :shutdown_called
      
      def init(evaluation_context)
        @initialized = true
        @init_context = evaluation_context
      end
      
      def shutdown
        @shutdown_called = true
      end
      
      def init_context
        @init_context
      end
    end
  end
  
  let(:provider) { test_class.new }
  
  describe 'interface methods' do
    it 'responds to init' do
      expect(provider).to respond_to(:init).with(1).argument
    end
    
    it 'responds to shutdown' do
      expect(provider).to respond_to(:shutdown).with(0).arguments
    end
  end
  
  describe '#init' do
    it 'can be called with evaluation context' do
      context = { user_id: '123' }
      provider.init(context)
      
      expect(provider.initialized).to be true
      expect(provider.init_context).to eq(context)
    end
    
    it 'has a default implementation that does nothing' do
      minimal_class = Class.new do
        include OpenFeature::SDK::Provider::StateHandler
      end
      
      minimal_provider = minimal_class.new
      expect { minimal_provider.init({}) }.not_to raise_error
    end
  end
  
  describe '#shutdown' do
    it 'can be called' do
      provider.shutdown
      expect(provider.shutdown_called).to be true
    end
    
    it 'has a default implementation that does nothing' do
      minimal_class = Class.new do
        include OpenFeature::SDK::Provider::StateHandler
      end
      
      minimal_provider = minimal_class.new
      expect { minimal_provider.shutdown }.not_to raise_error
    end
  end
  
  describe 'error handling' do
    let(:error_provider_class) do
      Class.new do
        include OpenFeature::SDK::Provider::StateHandler
        
        def init(evaluation_context)
          raise StandardError, "Initialization failed"
        end
        
        def shutdown
          raise StandardError, "Shutdown failed"
        end
      end
    end
    
    let(:error_provider) { error_provider_class.new }
    
    it 'propagates init errors' do
      expect { error_provider.init({}) }.to raise_error(StandardError, "Initialization failed")
    end
    
    it 'propagates shutdown errors' do
      expect { error_provider.shutdown }.to raise_error(StandardError, "Shutdown failed")
    end
  end
end