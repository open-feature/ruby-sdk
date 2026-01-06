# frozen_string_literal: true

require "spec_helper"
require "open_feature/sdk/provider/event_handler"
require "open_feature/sdk/provider_event"

RSpec.describe OpenFeature::SDK::Provider::EventHandler do
  let(:test_class) do
    Class.new do
      include OpenFeature::SDK::Provider::EventHandler

      def name
        "TestProvider"
      end
    end
  end

  let(:provider) { test_class.new }
  let(:event_dispatcher) { double("EventDispatcher") }

  describe "interface methods" do
    it "responds to emit_event" do
      expect(provider).to respond_to(:emit_event).with(1..2).arguments
    end

    it "responds to event_dispatcher_attached?" do
      expect(provider).to respond_to(:event_dispatcher_attached?).with(0).arguments
    end
  end

  describe "#attach" do
    it "attaches an event dispatcher" do
      provider.send(:attach, event_dispatcher)
      expect(provider.event_dispatcher_attached?).to be true
    end
  end

  describe "#detach" do
    it "detaches the event dispatcher" do
      provider.send(:attach, event_dispatcher)
      provider.send(:detach)
      expect(provider.event_dispatcher_attached?).to be false
    end
  end

  describe "#emit_event" do
    before do
      provider.send(:attach, event_dispatcher)
    end

    it "dispatches events through the attached dispatcher" do
      expect(event_dispatcher).to receive(:dispatch_event).with(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_READY,
        {}
      )

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
    end

    it "includes custom details in dispatched event" do
      custom_details = {message: "Provider is ready", custom_field: "value"}

      expect(event_dispatcher).to receive(:dispatch_event).with(
        provider,
        OpenFeature::SDK::ProviderEvent::PROVIDER_READY,
        {message: "Provider is ready", custom_field: "value"}
      )

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, custom_details)
    end

    it "does nothing when no dispatcher is attached" do
      provider.send(:detach)

      expect { provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }.not_to raise_error
    end

    it "raises error for invalid event type" do
      expect do
        provider.emit_event("INVALID_EVENT")
      end.to raise_error(ArgumentError, /Invalid event type/)
    end

    it "works with all valid event types" do
      OpenFeature::SDK::ProviderEvent::ALL_EVENTS.each do |event_type|
        expect(event_dispatcher).to receive(:dispatch_event).with(
          provider,
          event_type,
          {}
        )

        provider.emit_event(event_type)
      end
    end
  end

  describe "#event_dispatcher_attached?" do
    it "returns false when no dispatcher attached" do
      expect(provider.event_dispatcher_attached?).to be false
    end

    it "returns true when dispatcher attached" do
      provider.send(:attach, event_dispatcher)
      expect(provider.event_dispatcher_attached?).to be true
    end

    it "returns false after detaching" do
      provider.send(:attach, event_dispatcher)
      provider.send(:detach)
      expect(provider.event_dispatcher_attached?).to be false
    end
  end

  describe "thread safety" do
    it "handles concurrent attach/detach operations" do
      threads = []

      5.times do
        threads << Thread.new { provider.send(:attach, event_dispatcher) }
        threads << Thread.new { provider.send(:detach) }
      end

      threads.each(&:join)

      # Should not crash and should be in a valid state
      expect([true, false]).to include(provider.event_dispatcher_attached?)
    end
  end
end
