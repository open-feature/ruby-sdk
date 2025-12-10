# frozen_string_literal: true

require 'spec_helper'
require 'open_feature/sdk/provider/context_aware_state_handler'

RSpec.describe OpenFeature::SDK::Provider::ContextAwareStateHandler do
  let(:test_class) do
    Class.new do
      include OpenFeature::SDK::Provider::ContextAwareStateHandler
      
      attr_reader :init_called, :shutdown_called
      
      def init(evaluation_context)
        @init_called = true
        sleep(0.1) # Simulate some work
      end
      
      def shutdown
        @shutdown_called = true
        sleep(0.1) # Simulate some work
      end
    end
  end
  
  let(:provider) { test_class.new }
  
  describe 'interface methods' do
    it 'includes StateHandler methods' do
      expect(provider).to respond_to(:init).with(1).argument
      expect(provider).to respond_to(:shutdown).with(0).arguments
    end
    
    it 'responds to init_with_timeout' do
      expect(provider).to respond_to(:init_with_timeout).with(1).argument.and_keywords(:timeout)
    end
    
    it 'responds to shutdown_with_timeout' do
      expect(provider).to respond_to(:shutdown_with_timeout).with_keywords(:timeout)
    end
  end
  
  describe '#init_with_timeout' do
    it 'delegates to init by default' do
      provider.init_with_timeout({}, timeout: 1)
      expect(provider.init_called).to be true
    end
    
    it 'respects timeout' do
      slow_provider = Class.new do
        include OpenFeature::SDK::Provider::ContextAwareStateHandler
        
        def init(evaluation_context)
          sleep(1) # Sleep longer than timeout
        end
      end.new
      
      expect do
        slow_provider.init_with_timeout({}, timeout: 0.1)
      end.to raise_error(Timeout::Error)
    end
    
    it 'uses default timeout of 30 seconds' do
      # Just verify it accepts the call without timeout specified
      expect { provider.init_with_timeout({}) }.not_to raise_error
    end
  end
  
  describe '#shutdown_with_timeout' do
    it 'delegates to shutdown by default' do
      provider.shutdown_with_timeout(timeout: 1)
      expect(provider.shutdown_called).to be true
    end
    
    it 'respects timeout' do
      slow_provider = Class.new do
        include OpenFeature::SDK::Provider::ContextAwareStateHandler
        
        def shutdown
          sleep(1) # Sleep longer than timeout
        end
      end.new
      
      expect do
        slow_provider.shutdown_with_timeout(timeout: 0.1)
      end.to raise_error(Timeout::Error)
    end
    
    it 'uses default timeout of 10 seconds' do
      # Just verify it accepts the call without timeout specified
      expect { provider.shutdown_with_timeout }.not_to raise_error
    end
  end
  
  describe 'custom implementation' do
    let(:custom_class) do
      Class.new do
        include OpenFeature::SDK::Provider::ContextAwareStateHandler
        
        attr_reader :init_timeout_used, :shutdown_timeout_used
        
        def init_with_timeout(evaluation_context, timeout: 30)
          @init_timeout_used = timeout
          Timeout.timeout(timeout) do
            # Custom initialization with timeout awareness
            connect_with_retries(timeout)
          end
        end
        
        def shutdown_with_timeout(timeout: 10)
          @shutdown_timeout_used = timeout
          Timeout.timeout(timeout) do
            # Custom shutdown with timeout awareness
            graceful_disconnect(timeout)
          end
        end
        
        private
        
        def connect_with_retries(timeout)
          # Simulate connection logic
        end
        
        def graceful_disconnect(timeout)
          # Simulate disconnection logic
        end
      end
    end
    
    let(:custom_provider) { custom_class.new }
    
    it 'allows providers to override timeout methods' do
      custom_provider.init_with_timeout({}, timeout: 5)
      expect(custom_provider.init_timeout_used).to eq(5)
      
      custom_provider.shutdown_with_timeout(timeout: 3)
      expect(custom_provider.shutdown_timeout_used).to eq(3)
    end
  end
end