# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::Configuration do
  subject(:configuration) { described_class.new }

  describe "#set_provider" do
    context "when provider has an init method" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      it "inits and sets the provider" do
        expect(provider).to receive(:init)

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when provider does not have an init method" do
      it "sets the default provider" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        configuration.set_provider(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when domain is given" do
      it "binds the provider to that domain" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        expect(provider).to receive(:init)

        configuration.set_provider_and_wait(provider, domain: "testing")

        expect(configuration.provider(domain: "testing")).to be(provider)
      end
    end

    context "when the provider is set concurrently" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
      it "does not not call shutdown hooks multiple times if multithreaded" do
        providers = (0..2).map { OpenFeature::SDK::Provider::NoOpProvider.new }
        providers.each { |provider| allow(provider).to receive(:init) }
        providers[0, 2].each { |provider| allow(provider).to receive(:shutdown) }
        configuration.set_provider(providers[0])

        allow(providers[0]).to(receive(:shutdown).once { Timecop.travel(0.5) })
        background { configuration.set_provider(providers[1]) }
        background { configuration.set_provider(providers[2]) }
        yield_to_background
        expect(configuration.provider).to be(providers[2])
      end

      it "does not call shutdown on same provider instance when set multiple times concurrently" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        allow(provider).to receive(:init)
        # Provider should never be shut down since it's being set to itself
        expect(provider).not_to receive(:shutdown)

        configuration.set_provider(provider)
        background { configuration.set_provider(provider) }
        background { configuration.set_provider(provider) }
        yield_to_background

        expect(configuration.provider).to be(provider)
      end
    end
  end

  describe "#set_provider_and_wait" do
    context "when provider has a successful init method" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      it "waits for init to complete and sets the provider" do
        expect(provider).to receive(:init).once

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end

      it "initializes the provider synchronously" do
        expect(provider).to receive(:init).once

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when provider does not have an init method" do
      it "sets the provider without waiting" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when domain is given" do
      it "binds the provider to that domain" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        expect(provider).to receive(:init).once

        configuration.set_provider_and_wait(provider, domain: "testing")

        expect(configuration.provider(domain: "testing")).to be(provider)
      end
    end

    context "when provider init raises an exception" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
      let(:error_message) { "Database connection failed" }

      before do
        allow(provider).to receive(:init).and_raise(StandardError.new(error_message))
      end

      it "raises ProviderInitializationError" do
        expect do
          configuration.set_provider_and_wait(provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include("Provider initialization failed")
          expect(error.message).to include(error_message)
          expect(error.provider).to be(provider)
          expect(error.original_error).to be_a(StandardError) # Synchronous init preserves original exception
          expect(error.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL)
        end
      end

      it "leaves the failed provider in place when init fails" do
        configuration.provider

        expect do
          configuration.set_provider_and_wait(provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError)

        expect(configuration.provider).to be(provider)
      end
    end

    context "when shutting down the old provider fails" do
      let(:old_provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
      let(:new_provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      before do
        # Set up initial provider
        configuration.set_provider(old_provider)
        allow(old_provider).to receive(:shutdown).and_raise(StandardError.new("Shutdown failed"))
        allow(new_provider).to receive(:init)
      end

      it "continues with setting the new provider" do
        # Should not raise an exception even if shutdown fails
        configuration.set_provider_and_wait(new_provider)

        expect(configuration.provider).to be(new_provider)
      end
    end

    context "when the provider is set concurrently" do
      let(:providers) { (0..2).map { OpenFeature::SDK::Provider::InMemoryProvider.new } }

      it "handles concurrent calls safely" do
        providers.each { |provider| expect(provider).to receive(:init).once }
        # First two providers should be shut down
        expect(providers[0]).to receive(:shutdown).once
        expect(providers[1]).to receive(:shutdown).once

        configuration.set_provider_and_wait(providers[0])

        # Simulate slow initialization for concurrent testing
        allow(providers[0]).to receive(:shutdown) { Timecop.travel(0.1) }

        background { configuration.set_provider_and_wait(providers[1]) }
        background { configuration.set_provider_and_wait(providers[2]) }
        yield_to_background

        # The last provider should be set
        expect(configuration.provider).to be(providers[2])
      end
    end

    context "when handling complex initialization scenarios" do
      let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }

      it "handles provider that responds_to init but init is nil" do
        allow(provider).to receive(:respond_to?).with(:init).and_return(true)
        allow(provider).to receive(:respond_to?).with(:metadata).and_call_original
        allow(provider).to receive(:init).and_return(nil)

        configuration.set_provider_and_wait(provider)

        expect(configuration.provider).to be(provider)
      end

      it "handles setting provider to a domain with no previous provider" do
        # This should not raise any errors even though old_provider will be nil
        expect { configuration.set_provider_and_wait(provider, domain: "new-domain") }.not_to raise_error

        expect(configuration.provider(domain: "new-domain")).to be(provider)
      end
    end

    context "when evaluation context changes during async initialization" do
      let(:initial_context) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "initial") }
      let(:changed_context) { OpenFeature::SDK::EvaluationContext.new(targeting_key: "changed") }
      let(:context_capturing_provider) do
        Class.new do
          attr_reader :received_context

          def init(context = nil)
            @received_context = context
            # Simulate slow initialization
            Timecop.travel(0.1)
          end

          def metadata
            OpenFeature::SDK::Provider::ProviderMetadata.new(name: "ContextCapturingProvider")
          end
        end.new
      end

      it "uses the evaluation context that was set when set_provider was called" do
        configuration.evaluation_context = initial_context

        # Start provider initialization (async)
        configuration.set_provider(context_capturing_provider)

        # Change global context immediately after
        configuration.evaluation_context = changed_context

        # Wait for initialization to complete
        sleep(0.001) until context_capturing_provider.received_context

        # Provider should have received the initial context, not the changed one
        expect(context_capturing_provider.received_context).to eq(initial_context)
        expect(context_capturing_provider.received_context).not_to eq(changed_context)
      end
    end
  end

  describe "logger" do
    it "sets logger and propagates to event emitter" do
      logger = double("Logger")

      expect do
        configuration.logger = logger
      end.not_to raise_error

      expect(configuration.logger).to eq(logger)
      expect(configuration.instance_variable_get(:@event_dispatcher).instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe "provider initialization with different init signatures" do
    it "calls init without parameters when init method has no parameters" do
      provider = Class.new do
        attr_accessor :init_called

        def init
          @init_called = true
        end

        def metadata
          OpenFeature::SDK::Provider::ProviderMetadata.new(name: "TestProvider")
        end
      end.new

      configuration.set_provider(provider)

      # Wait for init to be called, check every millisecond
      sleep(0.001) until provider.init_called

      expect(provider.init_called).to be true
    end
  end

  describe "event handler error logging" do
    it "logs error when event handler fails and logger is present" do
      logger = double("Logger")
      configuration.logger = logger

      failing_handler = proc { |_| raise StandardError, "Handler failed" }

      configuration.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, failing_handler)

      expect(logger).to receive(:warn).with(/Event handler failed for/)

      configuration.send(:dispatch_provider_event,
        OpenFeature::SDK::Provider::NoOpProvider.new,
        OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
    end
  end

  describe "SDK lifecycle events" do
    it "emits PROVIDER_READY events for all provider types regardless of EventEmitter capability" do
      events_received = []
      handler = ->(event_details) { events_received << event_details[:provider_name] }

      configuration.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)

      event_handler_provider = Class.new do
        include OpenFeature::SDK::Provider::EventEmitter

        def init(_context)
        end

        def metadata
          OpenFeature::SDK::Provider::ProviderMetadata.new(name: "EventEmitter Provider")
        end
      end

      regular_provider = Class.new do
        def init(_context)
        end

        def metadata
          OpenFeature::SDK::Provider::ProviderMetadata.new(name: "Regular Provider")
        end
      end

      configuration.set_provider_and_wait(event_handler_provider.new)
      configuration.set_provider_and_wait(regular_provider.new)

      expect(events_received).to include("EventEmitter Provider", "Regular Provider")
    end

    it "emits PROVIDER_READY for providers without init methods" do
      events_received = []
      handler = ->(event_details) { events_received << event_details[:provider_name] }

      configuration.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
      configuration.set_provider_and_wait(OpenFeature::SDK::Provider::NoOpProvider.new)

      expect(events_received).to include("No-op Provider")
    end
  end
end
