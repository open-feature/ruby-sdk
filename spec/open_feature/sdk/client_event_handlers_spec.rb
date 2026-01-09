# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Client Event Handlers" do
  after do
    OpenFeature::SDK.configuration.send(:reset)
  end

  it "allows clients to add event handlers scoped to their domain" do
    # Clear providers to ensure clean state - no default provider should exist
    OpenFeature::SDK.configuration.instance_variable_set(:@providers, {})
    OpenFeature::SDK.configuration.instance_variable_get(:@provider_state_registry).instance_variable_set(:@states, {})

    events_received = []

    # Create client with specific domain
    client = OpenFeature::SDK.build_client(domain: "test_domain")

    # Add handler to client
    client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
      events_received << event
    end

    # Set provider for this domain
    OpenFeature::SDK.set_provider_and_wait(test_provider("TestProvider"), domain: "test_domain")

    # Should receive two events: one from SDK lifecycle, one from provider emit_event call
    # Note: Per Requirement 5.3.1, SDK automatically emits PROVIDER_READY when initialization terminates normally
    expect(events_received).to have_attributes(size: 2)
    expect(events_received[0][:provider_name]).to eq("TestProvider")
    expect(events_received[1][:provider_name]).to eq("TestProvider")
    expect(events_received[0]).not_to have_key(:provider_domain)
    expect(events_received[1]).not_to have_key(:provider_domain)
    expect(events_received[0]).not_to have_key(:provider)
  end

  it "does not trigger handlers for other domains" do
    # Clear providers to ensure clean state - no default provider should exist
    OpenFeature::SDK.configuration.instance_variable_set(:@providers, {})
    OpenFeature::SDK.configuration.instance_variable_get(:@provider_state_registry).instance_variable_set(:@states, {})

    events_received = []

    # Create client with specific domain
    client = OpenFeature::SDK.build_client(domain: "test_domain")

    # Add handler to client
    client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
      events_received << event
    end

    # Set provider for different domain
    OpenFeature::SDK.set_provider_and_wait(test_provider("OtherProvider"), domain: "other_domain")

    # Should not receive event
    expect(events_received).to be_empty
  end

  it "allows removal of client event handlers" do
    # Clear providers to ensure clean state - no default provider should exist
    OpenFeature::SDK.configuration.instance_variable_set(:@providers, {})
    OpenFeature::SDK.configuration.instance_variable_get(:@provider_state_registry).instance_variable_set(:@states, {})

    events_received = []

    client = OpenFeature::SDK.build_client(domain: "test_domain")

    handler = proc do |event|
      events_received << event
    end

    # Add then remove handler
    client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)
    client.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)

    OpenFeature::SDK.set_provider_and_wait(test_provider("TestProvider"), domain: "test_domain")

    # Should not receive event since handler was removed
    expect(events_received).to be_empty
  end

  it "supports block syntax for handlers" do
    # Clear providers to ensure clean state - no default provider should exist
    OpenFeature::SDK.configuration.instance_variable_set(:@providers, {})
    OpenFeature::SDK.configuration.instance_variable_get(:@provider_state_registry).instance_variable_set(:@states, {})

    events_received = []

    client = OpenFeature::SDK.build_client(domain: "test_domain")

    # Add handler using block syntax
    client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
      events_received << event
    end

    OpenFeature::SDK.set_provider_and_wait(test_provider("TestProvider"), domain: "test_domain")

    expect(events_received).to have_attributes(size: 2)
    expect(events_received[0][:provider_name]).to eq("TestProvider")
    expect(events_received[1][:provider_name]).to eq("TestProvider")
  end

  it "handles global domain (nil) correctly" do
    events_received = []

    # Create client without domain (global)
    client = OpenFeature::SDK.build_client

    client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
      events_received << event
    end

    # Set global provider
    OpenFeature::SDK.set_provider_and_wait(test_provider("TestProvider"))

    expect(events_received).to have_attributes(size: 2)
    expect(events_received[0][:provider_name]).to eq("TestProvider")
    expect(events_received[1][:provider_name]).to eq("TestProvider")
  end

  private

  def test_provider(name)
    Class.new do
      include OpenFeature::SDK::Provider::EventEmitter

      define_method :init do |evaluation_context = nil|
        # NOTE: Per Requirement 5.3.1, SDK automatically emits PROVIDER_READY when init terminates normally
        # Manual emission here results in duplicate events - kept for backward compatibility testing
        emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
      end

      define_method :metadata do
        OpenFeature::SDK::Provider::ProviderMetadata.new(name: name)
      end

      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: default_value,
          reason: OpenFeature::SDK::Provider::Reason::DEFAULT
        )
      end

      def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: default_value,
          reason: OpenFeature::SDK::Provider::Reason::DEFAULT
        )
      end

      def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: default_value,
          reason: OpenFeature::SDK::Provider::Reason::DEFAULT
        )
      end

      def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: default_value,
          reason: OpenFeature::SDK::Provider::Reason::DEFAULT
        )
      end

      def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: default_value,
          reason: OpenFeature::SDK::Provider::Reason::DEFAULT
        )
      end
    end.new
  end
end
