# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/open_feature/sdk"

RSpec.describe OpenFeature::SDK::Configuration do
  let(:configuration) { described_class.new }

  # Helper to create a provider that takes time to initialize
  def create_slow_provider(init_time: 0.1, &on_init)
    Class.new do
      define_method :init do |_evaluation_context|
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
      include OpenFeature::SDK::Provider::EventEmitter

      define_method :init do |_evaluation_context|
        sleep(init_time)
        on_init&.call
        emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
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
      include OpenFeature::SDK::Provider::EventEmitter

      define_method :init do |_evaluation_context|
        sleep(0.05) # Simulate some initialization time
        raise StandardError, error_message
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

        expect(elapsed).to be < 0.1 # Should return in less than 100ms
        expect(initialized).to be false # Should not be initialized yet

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
        expect(ready_events.first[:provider_name]).to eq(provider.class.name)
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
        expect(error_events.first[:provider_name]).to eq(provider.class.name)
        expect(error_events.first[:message]).to include("Init error")
      end
    end

    context "with event-aware providers" do
      it "emits PROVIDER_READY events from both SDK and provider" do
        ready_events = []
        configuration.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY,
          ->(event) { ready_events << event })

        provider = create_event_aware_provider(init_time: 0.05)
        configuration.set_provider(provider)

        # Wait for initialization
        sleep(0.15)

        # Should have two events: one from SDK lifecycle (per Requirement 5.3.1), one from provider emit_event call
        expect(ready_events.size).to eq(2)
      end
    end
  end

  describe "#set_provider_and_wait" do
    context "blocking behavior" do
      it "blocks until provider initialization completes" do
        initialized = false
        provider = create_slow_provider(init_time: 0.1) { initialized = true }

        expect(initialized).to be false
        configuration.set_provider_and_wait(provider)
        expect(initialized).to be true
      end

      it "returns only after PROVIDER_READY event" do
        provider = create_event_aware_provider(init_time: 0.1)

        start_time = Time.now
        configuration.set_provider_and_wait(provider)
        elapsed = Time.now - start_time

        expect(elapsed).to be >= 0.1 # Should wait at least as long as init time
      end
    end

    context "error handling" do
      it "raises ProviderInitializationError on provider initialization failure" do
        provider = create_failing_provider("Custom error")

        expect do
          configuration.set_provider_and_wait(provider)
        end.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include("Custom error")
        end
      end
    end
  end

  describe "provider state tracking" do
    it "tracks provider state transitions" do
      provider = create_slow_provider(init_time: 0.05)

      # Initially NOT_READY
      configuration.set_provider(provider)
      expect(configuration.send(:provider_state, provider)).to eq(OpenFeature::SDK::ProviderState::NOT_READY)

      # Wait for initialization
      sleep(0.1)
      expect(configuration.send(:provider_state, provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end

    it "tracks error states" do
      provider = create_failing_provider

      configuration.set_provider(provider)

      # Wait for initialization
      sleep(0.1)
      expect(configuration.send(:provider_state, provider)).to eq(OpenFeature::SDK::ProviderState::FATAL)
    end
  end

  describe "backward compatibility" do
    it "works with providers that don't use events" do
      provider = OpenFeature::SDK::Provider::NoOpProvider.new

      expect do
        configuration.set_provider_and_wait(provider)
      end.not_to raise_error

      expect(configuration.provider).to eq(provider)
    end
  end
end
