# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/open_feature/sdk"

RSpec.describe "OpenFeature Specification: Events" do
  before(:each) do
    OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::NoOpProvider.new)
  end

  after(:each) do
    OpenFeature::SDK.configuration.send(:reset)
  end

  context "Requirement 5.1.1" do
    specify "The feature provider interface MUST define a mechanism for signaling the occurrence of one of a set of events, with a provider event details payload" do
      # Verify that the EventEmitter mixin exists and can be included
      provider_class = Class.new do
        include OpenFeature::SDK::Provider::EventEmitter

        def init(_evaluation_context)
          # Provider can emit events
          emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        end

        def shutdown
          # no-op
        end
      end

      provider = provider_class.new
      expect(provider).to respond_to(:emit_event)
    end

    specify "the event set includes PROVIDER_RECONCILING and PROVIDER_CONTEXT_CHANGED" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      events = [OpenFeature::SDK::ProviderEvent::PROVIDER_RECONCILING, OpenFeature::SDK::ProviderEvent::PROVIDER_CONTEXT_CHANGED]
      received = []
      OpenFeature::SDK.set_provider_and_wait(provider)
      events.each do |event|
        OpenFeature::SDK.add_handler(event, ->(_details) { received << event })
        provider.emit_event(event)
      end
      expect(received).to eq(events)
    end
  end

  context "Requirement 5.1.2" do
    specify "When a provider signals the occurrence of a particular event, the associated client and API event handlers MUST run" do
      event_received = false
      handler = ->(_event_details) { event_received = true }

      # Add API-level handler
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)

      # Create event-aware provider
      provider_class = Class.new do
        include OpenFeature::SDK::Provider::EventEmitter

        def init(_evaluation_context)
          Thread.new do
            emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
          end
        end

        def shutdown
        end
      end

      provider = provider_class.new
      OpenFeature::SDK.set_provider(provider)

      # Wait for event, check every millisecond
      sleep(0.001) until event_received

      expect(event_received).to be true

      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    end

    specify "5.1.2: a handler that raises doesn't stop queued events" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      client = OpenFeature::SDK.build_client
      received = []
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, lambda do |_details|
        provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        raise "handler failed"
      end)
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(_details) { received << :ready })
      received.clear # Ignore the immediate callback during registration

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(received).to eq([:ready])
    end

    specify "5.1.2: a failing queued event doesn't turn a successful init into a failure" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      logger = spy("Logger")
      OpenFeature::SDK.configuration.logger = logger
      # Non-Hash details make the queued event fail while its handlers are prepared
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(_details) { provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, nil) })

      expect { OpenFeature::SDK.set_provider_and_wait(provider) }.not_to raise_error
      expect(OpenFeature::SDK.configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::STALE)
      expect(logger).to have_received(:error).with(/Queued provider event failed/)
    ensure
      OpenFeature::SDK.configuration.logger = nil
    end

    specify "5.1.2: a queued event is delivered with the details it was emitted with" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      received = nil
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, lambda do |_details|
        details = {message: "first"}
        provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED, details)
        details[:message] = "changed"
      end)
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED, ->(details) { received = details[:message] })

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(received).to eq("first")
    end

    specify "5.1.2: a queued event is dropped when its provider was replaced meanwhile" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      client = OpenFeature::SDK.build_client
      names = []
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, lambda do |_details|
        provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
        OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::NoOpProvider.new)
      end)
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(details) { names << details[:provider_name] })
      names.clear # Ignore the immediate callback during registration

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(names).to eq(["No-op Provider"])
    end

    specify "5.1.2: set_provider_and_wait for another provider from inside a handler returns READY" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      other = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      states = []
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, lambda do |_details|
        OpenFeature::SDK.set_provider_and_wait(other, domain: "x")
        states << OpenFeature::SDK.configuration.provider_state(other)
      end)

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(states).to eq([OpenFeature::SDK::ProviderState::READY])
    end

    specify "5.1.2: a client handler that raises is logged and doesn't stop the other client handlers" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      client = OpenFeature::SDK.build_client
      logger = spy("Logger")
      OpenFeature::SDK.configuration.logger = logger
      received = []
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, ->(_details) { raise "handler failed" })
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, ->(_details) { received << :stale })

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(received).to eq([:stale])
      expect(logger).to have_received(:error).with(/Client event handler failed: handler failed/)
    ensure
      OpenFeature::SDK.configuration.logger = nil
    end

    specify "5.1.2: a client handler can add another handler while handling an event" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      client = OpenFeature::SDK.build_client
      received = []
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, lambda do |_details|
        client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(_ready_details) { received << :ready })
      end)

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)
      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)

      expect(received).to eq([:ready])
    end

    specify "5.1.2: a client handler can emit an event for another provider" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      other = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider, domain: "a")
      OpenFeature::SDK.set_provider_and_wait(other, domain: "b")
      client = OpenFeature::SDK.build_client(domain: "a")
      other_client = OpenFeature::SDK.build_client(domain: "b")
      received = []
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, ->(_details) { other.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE) })
      other_client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, ->(_details) { received << :stale })

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(received).to eq([:stale])
    end
  end

  context "Requirement 5.1.3" do
    specify "When a provider signals the occurrence of a particular event, event handlers on clients which are not associated with that provider MUST NOT run" do
      events_received = []

      # Create client with specific domain
      client = OpenFeature::SDK.build_client(domain: "test_domain")

      # Add handler to client - this will receive immediate event from associated provider (global fallback)
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
        events_received << event
      end

      # Record initial event count (should have received 1 from global NoOpProvider fallback)
      initial_event_count = events_received.length
      expect(initial_event_count).to eq(1)

      # Create provider (SDK will automatically emit PROVIDER_READY after init)
      provider_class = Class.new do
        def init(_evaluation_context)
        end
      end

      # Set provider for different domain - this should NOT trigger the client's handler
      OpenFeature::SDK.set_provider_and_wait(provider_class.new, domain: "other_domain")

      # Client handler should not receive any NEW events from different domain
      expect(events_received.length).to eq(initial_event_count)
    end
  end

  context "Requirement 5.1.4" do
    specify "PROVIDER_ERROR events SHOULD populate the error message field" do
      event_details_received = nil
      handler = ->(event_details) { event_details_received = event_details }

      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)

      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_raise("Custom init failure")

      OpenFeature::SDK.set_provider(provider)
      sleep(0.001) until event_details_received

      expect(event_details_received[:message]).to eq("Custom init failure")

      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)
    end
  end

  context "Requirement 5.1.5" do
    specify "PROVIDER_ERROR events SHOULD populate the error code field" do
      event_details_received = nil
      handler = ->(event_details) { event_details_received = event_details }

      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)

      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_raise("Init failed")

      OpenFeature::SDK.set_provider(provider)
      sleep(0.001) until event_details_received

      expect(event_details_received[:error_code]).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)

      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)
    end

    specify "error details are available in immediate handlers attached after the error" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_raise("Delayed failure")

      begin
        OpenFeature::SDK.set_provider_and_wait(provider)
      rescue OpenFeature::SDK::ProviderInitializationError
        # Expected — provider init fails, putting provider in ERROR state
      end

      event_details_received = nil
      handler = ->(event_details) { event_details_received = event_details }

      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)

      expect(event_details_received).not_to be_nil
      expect(event_details_received[:error_code]).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)
      expect(event_details_received[:message]).to eq("Delayed failure")

      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler)
    end
  end

  context "Requirement 5.2.1" do
    specify "The client MUST provide a function for associating handler functions with provider event types" do
      client = OpenFeature::SDK.build_client(domain: "test-domain")

      # Verify client has methods to associate handlers with provider event types
      expect(client).to respond_to(:add_handler)
      expect(client).to respond_to(:remove_handler)

      handler1 = ->(event_details) {}
      handler2 = ->(event_details) {}

      # Test adding handlers for all provider event types
      expect do
        client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
        client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler1)
        client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, handler1)
        client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED, handler1)
      end.not_to raise_error

      # Test multiple handlers for the same event type
      expect do
        client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)
      end.not_to raise_error

      # Verify handlers are stored in global configuration
      client_handlers = OpenFeature::SDK.configuration.instance_variable_get(:@client_handlers)
      expect(client_handlers).to have_key(client)
      expect(client_handlers[client][OpenFeature::SDK::ProviderEvent::PROVIDER_READY]).to include(handler1, handler2)
      expect(client_handlers[client][OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR]).to include(handler1)

      # Test removing handlers
      expect do
        client.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
        client.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, handler1)
        client.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, handler1)
        client.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_CONFIGURATION_CHANGED, handler1)
      end.not_to raise_error

      # Verify handler1 is removed, handler2 remains
      client_handlers = OpenFeature::SDK.configuration.instance_variable_get(:@client_handlers)
      expect(client_handlers[client][OpenFeature::SDK::ProviderEvent::PROVIDER_READY]).not_to include(handler1)
      expect(client_handlers[client][OpenFeature::SDK::ProviderEvent::PROVIDER_READY]).to include(handler2)
      expect(client_handlers[client][OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR]).to be_empty

      # Test removing the remaining handler
      expect do
        client.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)
      end.not_to raise_error

      # Verify all handlers are removed
      client_handlers = OpenFeature::SDK.configuration.instance_variable_get(:@client_handlers)
      expect(client_handlers[client][OpenFeature::SDK::ProviderEvent::PROVIDER_READY]).to be_empty
    end

    specify "rejects a client handler for an unknown event type or one that can't be called" do
      client = OpenFeature::SDK.build_client

      expect { client.add_handler("NOPE", ->(_details) {}) }.to raise_error(ArgumentError, /Invalid event type/)
      expect { client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) }.to raise_error(ArgumentError, /Handler must respond to call/)
    end
  end

  context "Requirement 5.2.2" do
    specify "The API MUST provide a function for associating handler functions with provider event types" do
      expect(OpenFeature::SDK).to respond_to(:add_handler)
      expect(OpenFeature::SDK).to respond_to(:remove_handler)

      # Verify handlers can be added and removed
      handler = ->(event_details) {}

      expect do
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      end.not_to raise_error

      expect do
        OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      end.not_to raise_error
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

      # Wait for event, check every millisecond
      sleep(0.001) until event_details_received

      expect(event_details_received).not_to be_nil
      expect(event_details_received).to be_a(Hash)
      expect(event_details_received[:provider_name]).to eq("In-memory Provider")
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

      failing_handler = ->(_event_details) { raise "Handler error" }
      handler1 = ->(_event_details) { handler1_called = true }
      handler2 = ->(_event_details) { handler2_called = true }
      handler3 = ->(_event_details) { handler3_called = true }

      # Add handlers in order
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler1)
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, failing_handler)
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler2)
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler3)

      # Set provider
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)

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
      handler_call_count = 0
      handler = ->(_event_details) { handler_call_count += 1 }

      # Add handler after initial provider is already set and ready
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)

      # Set first provider
      provider1 = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider1)

      # Should be exactly 2: 1 immediate (current provider READY) + 1 from InMemoryProvider lifecycle
      expect(handler_call_count).to eq(2)

      # Set second provider - handler should still be active
      provider2 = OpenFeature::SDK::Provider::NoOpProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider2)

      # Should be exactly 3: 1 immediate + 2 from previous provider changes
      expect(handler_call_count).to eq(3)

      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    end
  end

  context "Requirement 5.2.7" do
    after { OpenFeature::SDK.configuration.logger = nil }

    specify "5.2.7: a client handler can remove itself while handling an event" do
      logger = spy("Logger")
      OpenFeature::SDK.configuration.logger = logger
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      client = OpenFeature::SDK.build_client
      calls = 0
      handler = lambda do |_details|
        calls += 1
        client.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, handler)
      end
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, handler)

      2.times { provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE) }

      expect(calls).to eq(1)
      expect(logger).not_to have_received(:error)
    end
  end

  context "Requirement 5.3.1" do
    specify "If the provider's initialize function terminates normally, PROVIDER_READY handlers MUST run" do
      ready_event_received = false
      handler = ->(_event_details) { ready_event_received = true }

      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)

      # Provider with successful init
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_return(nil) # Normal termination

      OpenFeature::SDK.set_provider_and_wait(provider)

      expect(ready_event_received).to be true

      # Cleanup
      OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    end
  end

  context "Requirement 5.3.3" do
    describe "Handlers attached after the provider is already in the associated state, MUST run immediately" do
      context "API-level handlers" do
        specify "PROVIDER_READY handler runs immediately when provider is already READY" do
          events_received = []

          provider = OpenFeature::SDK::Provider::InMemoryProvider.new
          OpenFeature::SDK.set_provider_and_wait(provider)

          handler = ->(event) { events_received << event }
          OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)

          expect(events_received.size).to be >= 1
          # Event for current READY provider: In-memory Provider
          # May receive multiple events when run as part of full test suite
          provider_names = events_received.map { |event| event[:provider_name] }
          expect(provider_names).to include("In-memory Provider")

          OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
        end

        specify "5.3.3: an API handler runs once for a READY provider bound to two domains" do
          provider = OpenFeature::SDK::Provider::InMemoryProvider.new
          OpenFeature::SDK.set_provider_and_wait(provider, domain: "a")
          OpenFeature::SDK.set_provider_and_wait(provider, domain: "b")
          names = []

          OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(details) { names << details[:provider_name] })

          expect(names.count("In-memory Provider")).to eq(1)
        end
      end

      context "Client-level handlers" do
        specify "PROVIDER_READY handler runs immediately when provider is already READY" do
          events_received = []

          provider = OpenFeature::SDK::Provider::InMemoryProvider.new
          OpenFeature::SDK.set_provider_and_wait(provider, domain: "immediate_test")

          client = OpenFeature::SDK.build_client(domain: "immediate_test")
          client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
            events_received << event
          end

          expect(events_received).to have_attributes(size: 1)
          expect(events_received[0][:provider_name]).to eq("In-memory Provider")
        end
      end
    end
  end

  context "Requirement 5.3.5" do
    specify "1.1.2.4: set_provider_and_wait from the provider's own ERROR handler returns with the provider READY" do
      outcomes = Queue.new
      outcomes << :fail << :ok
      provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
        define_method(:init) { |_evaluation_context = nil| raise "init failed" if outcomes.pop == :fail }
      end.new
      retried = false
      state_after_retry = nil
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, lambda do |_details|
        next if retried

        retried = true
        OpenFeature::SDK.set_provider_and_wait(provider)
        state_after_retry = OpenFeature::SDK.configuration.provider_state(provider)
      end)

      expect { OpenFeature::SDK.set_provider_and_wait(provider) }.to raise_error(OpenFeature::SDK::ProviderInitializationError)
      expect(state_after_retry).to eq(OpenFeature::SDK::ProviderState::READY)
    end

    [[:ERROR, :READY], [:READY, :STALE]].each do |first, following|
      specify "5.3.5: a nested event for the same provider is delivered after the current one (#{first}, then #{following})" do
        first_event, following_event = [first, following].map { |name| OpenFeature::SDK::ProviderEvent.const_get(:"PROVIDER_#{name}") }
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)
        provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)
        client = OpenFeature::SDK.build_client
        events = []
        OpenFeature::SDK.add_handler(first_event, ->(_details) { provider.emit_event(following_event) })
        client.add_handler(first_event, ->(_details) { events << first })
        client.add_handler(following_event, ->(_details) { events << following })
        events.clear # Ignore immediate callbacks during registration

        provider.emit_event(first_event)

        expect(events).to eq([first, following])
      end
    end

    specify "5.3.5: client handlers of the outer event observe the outer event's status" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      OpenFeature::SDK.set_provider_and_wait(provider)
      client = OpenFeature::SDK.build_client
      statuses = []
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, ->(_details) { provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) })
      client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, ->(_details) { statuses << client.provider_status })

      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR)

      expect(statuses).to eq([OpenFeature::SDK::ProviderState::ERROR])
    end

    specify "5.3.5: a stale READY from an earlier registration is dropped" do
      gates = [Queue.new, Queue.new]
      first_init, second_init = gates
      provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
        define_method(:init) { |_evaluation_context = nil| gates.shift.pop }
      end.new
      init_threads = []
      allow(Thread).to receive(:new).and_wrap_original { |original, *args, &block| original.call(*args, &block).tap { |t| init_threads << t } }

      OpenFeature::SDK.set_provider(provider)
      500.times { first_init.num_waiting.positive? ? break : sleep(0.01) }
      expect(first_init.num_waiting).to eq(1)
      OpenFeature::SDK.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new)
      OpenFeature::SDK.set_provider(provider)

      first_init << :ok
      expect(init_threads.first.join(5)).to be(init_threads.first)
      expect(OpenFeature::SDK.configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)

      second_init << :ok
      expect(init_threads.last.join(5)).to be(init_threads.last)
      expect(OpenFeature::SDK.configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end
  end
end
