# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Client Event Handlers" do
  before do
    # Ensure clean state before each test
    begin
      # Clear handlers from any existing configuration
      OpenFeature::SDK.configuration.clear_all_handlers if OpenFeature::SDK.instance_variable_get(:@instance)
    rescue
      # Ignore errors if configuration doesn't exist
    end
    # Reset the singleton instance to get a fresh configuration
    OpenFeature::SDK.instance_variable_set(:@instance, nil)
  end

  after do
    # Reset providers to clean state between tests
    OpenFeature::SDK.instance_variable_get(:@instance)&.instance_variable_set(:@configuration, nil)
  end

  it "allows clients to add event handlers scoped to their domain" do
    events_received = []

    # Create client with specific domain
    client = OpenFeature::SDK.build_client(domain: "test_domain")

    # Add handler to client
    client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
      events_received << event
    end

    # Set provider for this domain
    OpenFeature::SDK.set_provider_and_wait(test_provider("TestProvider"), domain: "test_domain")

    # Should receive event
    expect(events_received).to have_attributes(size: 1)
    expect(events_received[0][:provider_name]).to eq("TestProvider")
    expect(events_received[0]).not_to have_key(:provider_domain)
    expect(events_received[0]).not_to have_key(:provider)
  end

  it "does not trigger handlers for other domains" do
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
    events_received = []

    client = OpenFeature::SDK.build_client(domain: "test_domain")

    # Add handler using block syntax
    client.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY) do |event|
      events_received << event
    end

    OpenFeature::SDK.set_provider_and_wait(test_provider("TestProvider"), domain: "test_domain")

    expect(events_received).to have_attributes(size: 1)
    expect(events_received[0][:provider_name]).to eq("TestProvider")
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

    expect(events_received).to have_attributes(size: 1)
    expect(events_received[0][:provider_name]).to eq("TestProvider")
  end

  private

  def test_provider(name = "TestProvider")
    Class.new do
      include OpenFeature::SDK::Provider::EventHandler

      define_method :init do |evaluation_context = nil|
        # Providers implementing EventHandler must emit their own events
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
