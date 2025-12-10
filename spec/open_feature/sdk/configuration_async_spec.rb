require "spec_helper"
require_relative "../../../lib/open_feature/sdk"

RSpec.describe OpenFeature::SDK::Configuration do
  let(:configuration) { described_class.new }
  
  # Helper to create a provider that takes time to initialize
  def create_slow_provider(init_time: 0.1, &on_init)
    Class.new do
      define_method :init do |evaluation_context|
        sleep(init_time)
        on_init&.call
      end
      
      def shutdown
        # no-op
      end
      
      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: default_value,
          reason: OpenFeature::SDK::Provider::Reason::DEFAULT
        )
      end
    end.new
  end
  
  # Helper to create an event-aware provider
  def create_event_aware_provider(init_time: 0.1, &on_init)
    Class.new do
      include OpenFeature::SDK::Provider::EventHandler
      
      define_method :init do |evaluation_context|
        Thread.new do
          sleep(init_time)
          on_init&.call
          emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        end
      end
      
      def shutdown
        # no-op
      end
      
      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: default_value,
          reason: OpenFeature::SDK::Provider::Reason::DEFAULT
        )
      end
    end.new
  end
  
  # Helper to create a failing provider
  def create_failing_provider(error_message = "Init failed")
    Class.new do
      include OpenFeature::SDK::Provider::EventHandler
      
      define_method :init do |evaluation_context|
        Thread.new do
          sleep(0.05)
          emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, 
                    error_code: 'PROVIDER_FATAL',
                    message: error_message)
        end
      end
      
      def shutdown
        # no-op
      end
    end.new
  end
  
  describe "#set_provider" do
    context "non-blocking behavior" do
      it "returns immediately without waiting for initialization" do
        initialized = false
        provider = create_slow_provider(init_time: 0.2) { initialized = true }
        
        start_time = Time.now
        configuration.set_provider(provider)
        elapsed = Time.now - start_time
        
        expect(elapsed).to be < 0.1  # Should return in less than 100ms
        expect(initialized).to be false  # Should not be initialized yet
        
        # Wait for initialization to complete
        sleep(0.3)
        expect(initialized).to be true
      end
      
      it "sets the provider before initialization completes" do
        provider = create_slow_provider(init_time: 0.1)
        
        configuration.set_provider(provider)
        
        # Provider should be set immediately
        expect(configuration.provider).to eq(provider)
      end
    end
    
    context "event emission" do
      it "emits PROVIDER_READY event after successful initialization" do
        ready_events = []
        configuration.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, 
                                 ->(event) { ready_events << event })
        
        provider = create_slow_provider(init_time: 0.05)
        configuration.set_provider(provider)
        
        # Wait for initialization
        sleep(0.1)
        
        expect(ready_events.size).to eq(1)
        expect(ready_events.first[:provider]).to eq(provider)
      end
      
      it "emits PROVIDER_ERROR event on initialization failure" do
        error_events = []
        configuration.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, 
                                 ->(event) { error_events << event })
        
        provider = create_slow_provider { raise "Init error" }
        configuration.set_provider(provider)
        
        # Wait for initialization
        sleep(0.2)
        
        expect(error_events.size).to eq(1)
        expect(error_events.first[:provider]).to eq(provider)
        expect(error_events.first[:message]).to include("Init error")
      end
    end
    
    context "with event-aware providers" do
      it "does not emit duplicate PROVIDER_READY events" do
        ready_events = []
        configuration.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, 
                                 ->(event) { ready_events << event })
        
        provider = create_event_aware_provider(init_time: 0.05)
        configuration.set_provider(provider)
        
        # Wait for initialization
        sleep(0.15)
        
        # Should only have one event (from the provider itself)
        expect(ready_events.size).to eq(1)
      end
    end
  end
  
  describe "#set_provider_and_wait" do
    context "blocking behavior" do
      it "blocks until provider initialization completes" do
        initialized = false
        provider = create_slow_provider(init_time: 0.1) { initialized = true }
        
        expect(initialized).to be false
        configuration.set_provider_and_wait(provider, timeout: 1)
        expect(initialized).to be true
      end
      
      it "returns only after PROVIDER_READY event" do
        provider = create_event_aware_provider(init_time: 0.1)
        
        start_time = Time.now
        configuration.set_provider_and_wait(provider, timeout: 1)
        elapsed = Time.now - start_time
        
        expect(elapsed).to be >= 0.1  # Should wait at least as long as init time
      end
    end
    
    context "error handling" do
      it "raises ProviderInitializationError on provider initialization failure" do
        provider = create_failing_provider("Custom error")
        
        expect {
          configuration.set_provider_and_wait(provider, timeout: 1)
        }.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include("Custom error")
        end
      end
      
      it "raises ProviderInitializationError on timeout" do
        provider = create_slow_provider(init_time: 2.0)  # 2 seconds
        
        expect {
          configuration.set_provider_and_wait(provider, timeout: 0.5)
        }.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include("timed out after 0.5 seconds")
        end
      end
    end
    
    context "event handler cleanup" do
      it "removes event handlers after completion" do
        provider = create_slow_provider(init_time: 0.05)
        
        # Get initial handler count
        initial_ready_count = configuration.instance_variable_get(:@event_emitter)
                                         .instance_variable_get(:@handlers)[OpenFeature::SDK::ProviderEvent::PROVIDER_READY].size
        initial_error_count = configuration.instance_variable_get(:@event_emitter)
                                         .instance_variable_get(:@handlers)[OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR].size
        
        configuration.set_provider_and_wait(provider, timeout: 1)
        
        # Handler counts should be back to initial
        final_ready_count = configuration.instance_variable_get(:@event_emitter)
                                       .instance_variable_get(:@handlers)[OpenFeature::SDK::ProviderEvent::PROVIDER_READY].size
        final_error_count = configuration.instance_variable_get(:@event_emitter)
                                       .instance_variable_get(:@handlers)[OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR].size
        
        expect(final_ready_count).to eq(initial_ready_count)
        expect(final_error_count).to eq(initial_error_count)
      end
      
      it "removes event handlers even on error" do
        provider = create_failing_provider
        
        # Get initial handler count
        initial_count = configuration.instance_variable_get(:@event_emitter)
                                   .instance_variable_get(:@handlers).values.sum(&:size)
        
        expect {
          configuration.set_provider_and_wait(provider, timeout: 1)
        }.to raise_error(OpenFeature::SDK::ProviderInitializationError)
        
        # Handler count should be back to initial
        final_count = configuration.instance_variable_get(:@event_emitter)
                                 .instance_variable_get(:@handlers).values.sum(&:size)
        
        expect(final_count).to eq(initial_count)
      end
    end
  end
  
  describe "provider state tracking" do
    it "tracks provider state transitions" do
      provider = create_slow_provider(init_time: 0.05)
      state_registry = configuration.instance_variable_get(:@provider_state_registry)
      
      # Initially NOT_READY
      configuration.set_provider(provider)
      expect(state_registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
      
      # Wait for initialization
      sleep(0.1)
      expect(state_registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end
    
    it "tracks error states" do
      provider = create_failing_provider
      state_registry = configuration.instance_variable_get(:@provider_state_registry)
      
      configuration.set_provider(provider)
      
      # Wait for initialization
      sleep(0.1)
      expect(state_registry.get_state(provider)).to eq(OpenFeature::SDK::ProviderState::FATAL)
    end
  end
  
  describe "backward compatibility" do
    it "works with providers that don't use events" do
      provider = OpenFeature::SDK::Provider::NoOpProvider.new
      
      expect {
        configuration.set_provider_and_wait(provider, timeout: 1)
      }.not_to raise_error
      
      expect(configuration.provider).to eq(provider)
    end
  end
end