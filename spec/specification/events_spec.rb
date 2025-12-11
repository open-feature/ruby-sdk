require "spec_helper"
require_relative "../../lib/open_feature/sdk"

RSpec.describe "OpenFeature Specification: Events" do
  before(:each) do
    # Reset to default provider
    OpenFeature::SDK.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new)
  end
  
  # Remove all handlers after each test to avoid test pollution
  after(:each) do
    # Clean up any remaining handlers
    [
      OpenFeature::SDK::ProviderEvent::PROVIDER_READY,
      OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR,
      OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED,
      OpenFeature::SDK::ProviderEvent::PROVIDER_STALE
    ].each do |event|
      begin
        # This is a bit hacky but we need to clean up
        emitter = OpenFeature::SDK::API.instance.configuration.instance_variable_get(:@event_emitter)
        emitter.instance_variable_get(:@handlers)[event].clear
      rescue
        # Ignore errors
      end
    end
  end

  context "Requirement 5.1.1" do
    specify "The provider MAY define a mechanism for signaling the occurrence of events" do
      # Verify that the EventHandler mixin exists and can be included
      provider_class = Class.new do
        include OpenFeature::SDK::Provider::EventHandler
        
        def init(evaluation_context)
          # Provider can emit events
          emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        end
        
        def shutdown
          # no-op
        end
      end
      
      provider = provider_class.new
      expect(provider).to respond_to(:emit_event)
      expect(provider).to respond_to(:attach)
      expect(provider).to respond_to(:detach)
    end
  end

  context "Requirement 5.1.2" do
    specify "When a provider signals the occurrence of a particular event, the associated client and API event handlers MUST run" do
      event_received = false
      handler = ->(event_details) { event_received = true }
      
      # Add API-level handler
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      
      # Create event-aware provider
      provider_class = Class.new do
        include OpenFeature::SDK::Provider::EventHandler
        
        def init(evaluation_context)
          Thread.new do
            sleep(0.05)
            emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
          end
        end
        
        def shutdown; end
      end
      
      provider = provider_class.new
      OpenFeature::SDK.set_provider(provider)
      
      # Wait for event
      sleep(0.1)
      
      expect(event_received).to be true
      
      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    end
  end

  context "Requirement 5.2.1" do
    specify "The client MUST provide a function for associating handler functions with provider event types" do
      # NOTE: In the current Ruby SDK implementation, event handlers are managed at the API level,
      # not the client level. This is a known deviation from the specification.
      # Clients inherit event behavior through their providers.
      skip "Client-level event handlers not yet implemented in Ruby SDK"
    end
  end

  context "Requirement 5.2.2" do
    specify "The API MUST provide a function for associating handler functions with provider event types" do
      expect(OpenFeature::SDK).to respond_to(:add_handler)
      expect(OpenFeature::SDK).to respond_to(:remove_handler)
      
      # Verify handlers can be added and removed
      handler = ->(event_details) { }
      
      expect {
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      }.not_to raise_error
      
      expect {
        OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      }.not_to raise_error
    end
  end

  context "Requirement 5.2.4" do
    specify "Event handler functions MUST accept an event details parameter" do
      event_details_received = nil
      handler = ->(event_details) { event_details_received = event_details }
      
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)
      
      # Set provider that fails initialization
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_raise("Init failed")
      
      OpenFeature::SDK.set_provider(provider)
      sleep(0.1)  # Wait for async initialization
      
      expect(event_details_received).not_to be_nil
      expect(event_details_received).to be_a(Hash)
      expect(event_details_received[:provider]).to eq(provider)
      expect(event_details_received[:message]).to include("Init failed")
      
      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)
    end
  end

  context "Requirement 5.2.5" do
    specify "If an event handler function terminates abnormally, other handler functions MUST still be invoked" do
      handler1_called = false
      handler2_called = false
      handler3_called = false
      
      failing_handler = ->(event_details) { raise "Handler error" }
      handler1 = ->(event_details) { handler1_called = true }
      handler2 = ->(event_details) { handler2_called = true }
      handler3 = ->(event_details) { handler3_called = true }
      
      # Add handlers in order
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, failing_handler)
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler3)
      
      # Set provider
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider(provider)
      sleep(0.1)  # Wait for async initialization
      
      # All handlers should have been called despite the failure
      expect(handler1_called).to be true
      expect(handler2_called).to be true
      expect(handler3_called).to be true
      
      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, failing_handler)
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler3)
    end
  end

  context "Requirement 5.2.6" do
    specify "Event handlers MUST persist across provider changes" do
      # Wait for initial provider to be ready
      sleep(0.1)
      
      handler_call_count = 0
      handler = ->(event_details) { handler_call_count += 1 }
      
      # Add handler after initial provider is already set and ready
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      
      # Set first provider
      provider1 = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider(provider1)
      sleep(0.1)
      
      expect(handler_call_count).to eq(1)
      
      # Set second provider - handler should still be active
      provider2 = OpenFeature::SDK::Provider::NoOpProvider.new  
      OpenFeature::SDK.set_provider(provider2)
      sleep(0.1)
      
      expect(handler_call_count).to eq(2)
      
      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    end
  end

  context "Requirement 5.3.1" do
    specify "If the provider's initialize function terminates normally, PROVIDER_READY handlers MUST run" do
      ready_event_received = false
      handler = ->(event_details) { ready_event_received = true }
      
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      
      # Provider with successful init
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_return(nil)  # Normal termination
      
      OpenFeature::SDK.set_provider(provider)
      sleep(0.1)  # Wait for async initialization
      
      expect(ready_event_received).to be true
      
      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    end
  end

  context "Requirement 5.3.3" do
    specify "Handlers attached after the provider is already in the associated state, MUST run immediately" do
      # NOTE: This requirement is about handlers running immediately when attached after a provider
      # is already in the associated state (e.g., READY). This feature is not yet implemented
      # in the Ruby SDK. Handlers are only triggered by state transitions, not by current state.
      skip "Immediate handler execution for current state not yet implemented"
    end
  end
end
