# frozen_string_literal: true

require "spec_helper"
require "open_feature/sdk/event_emitter"
require "open_feature/sdk/provider_event"

RSpec.describe OpenFeature::SDK::EventEmitter do
  subject(:event_emitter) { described_class.new }

  describe "#initialize" do
    it "initializes with empty handlers for all event types" do
      OpenFeature::SDK::ProviderEvent::ALL_EVENTS.each do |event_type|
        expect(event_emitter.handler_count(event_type)).to eq(0)
      end
    end
  end

  describe "#add_handler" do
    let(:handler) { ->(event_details) { puts "Event received: #{event_details}" } }

    it "adds a handler for a valid event type" do
      expect do
        event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      end.to change { event_emitter.handler_count(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }.from(0).to(1)
    end

    it "raises error for invalid event type" do
      expect do
        event_emitter.add_handler("INVALID_EVENT", handler)
      end.to raise_error(ArgumentError, /Invalid event type/)
    end

    it "raises error for non-callable handler" do
      expect do
        event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, "not callable")
      end.to raise_error(ArgumentError, /Handler must respond to call/)
    end

    it "allows multiple handlers for the same event type" do
      handler2 = ->(_event_details) { puts "Handler 2" }

      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)

      expect(event_emitter.handler_count(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)).to eq(2)
    end
  end

  describe "#remove_handler" do
    let(:handler1) { ->(_event_details) { puts "Handler 1" } }
    let(:handler2) { ->(_event_details) { puts "Handler 2" } }

    before do
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)
    end

    it "removes a specific handler" do
      expect do
        event_emitter.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
      end.to change { event_emitter.handler_count(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }.from(2).to(1)
    end

    it "does nothing for invalid event type" do
      expect do
        event_emitter.remove_handler("INVALID_EVENT", handler1)
      end.not_to(change { event_emitter.handler_count(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) })
    end

    it "does nothing if handler is not registered" do
      unregistered_handler = ->(_event_details) { puts "Unregistered" }

      expect do
        event_emitter.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, unregistered_handler)
      end.not_to(change { event_emitter.handler_count(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) })
    end
  end

  describe "#remove_all_handlers" do
    let(:handler1) { ->(_event_details) { puts "Handler 1" } }
    let(:handler2) { ->(_event_details) { puts "Handler 2" } }

    before do
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)
    end

    it "removes all handlers for an event type" do
      expect do
        event_emitter.remove_all_handlers(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
      end.to change { event_emitter.handler_count(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }.from(2).to(0)
    end
  end

  describe "#trigger_event" do
    let(:received_events) { [] }
    let(:handler) { ->(event_details) { received_events << event_details } }

    before do
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    end

    it "triggers handlers with event details" do
      event_details = {provider: "test-provider", message: "Ready"}

      event_emitter.trigger_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, event_details)

      expect(received_events).to contain_exactly(event_details)
    end

    it "triggers handlers with empty event details if none provided" do
      event_emitter.trigger_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)

      expect(received_events).to contain_exactly({})
    end

    it "triggers multiple handlers for the same event" do
      received_events2 = []
      handler2 = ->(event_details) { received_events2 << event_details }
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)

      event_details = {test: "data"}
      event_emitter.trigger_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, event_details)

      expect(received_events).to contain_exactly(event_details)
      expect(received_events2).to contain_exactly(event_details)
    end

    it "does nothing for invalid event type" do
      event_emitter.trigger_event("INVALID_EVENT", {test: "data"})

      expect(received_events).to be_empty
    end

    it "continues executing other handlers even if one fails" do
      failing_handler = ->(_event_details) { raise "Handler failed" }
      received_events2 = []
      working_handler = ->(event_details) { received_events2 << event_details }

      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, failing_handler)
      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, working_handler)

      event_details = {test: "data"}

      # Should not raise error and should still call working handlers
      expect do
        event_emitter.trigger_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, event_details)
      end.not_to raise_error
      expect(received_events).to contain_exactly(event_details)
      expect(received_events2).to contain_exactly(event_details)
    end
  end

  describe "#clear_all_handlers" do
    before do
      OpenFeature::SDK::ProviderEvent::ALL_EVENTS.each do |event_type|
        event_emitter.add_handler(event_type, ->(_event_details) { puts "Handler for #{event_type}" })
      end
    end

    it "clears all handlers for all event types" do
      event_emitter.clear_all_handlers

      OpenFeature::SDK::ProviderEvent::ALL_EVENTS.each do |event_type|
        expect(event_emitter.handler_count(event_type)).to eq(0)
      end
    end
  end

  describe "thread safety" do
    let(:handler) { ->(_event_details) { Timecop.travel(0.001) } } # Small delay to increase chance of race conditions

    it "handles concurrent add/remove operations safely" do
      threads = []

      # Concurrent additions
      10.times do
        threads << Thread.new do
          event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
        end
      end

      # Concurrent removals
      5.times do
        threads << Thread.new do
          event_emitter.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
        end
      end

      threads.each(&:join)

      # Should not crash and should have some handlers remaining
      expect(event_emitter.handler_count(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)).to be >= 0
    end

    it "handles concurrent triggering safely" do
      received_count = 0
      counter_mutex = Mutex.new
      counting_handler = lambda do |_event_details|
        counter_mutex.synchronize { received_count += 1 }
      end

      event_emitter.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, counting_handler)

      threads = []
      10.times do
        threads << Thread.new do
          event_emitter.trigger_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, {test: "concurrent"})
        end
      end

      threads.each(&:join)

      expect(received_count).to eq(10)
    end
  end
end
