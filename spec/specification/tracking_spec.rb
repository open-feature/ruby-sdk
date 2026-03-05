# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tracking Specification" do
  before(:each) do
    OpenFeature::SDK::API.instance.send(:configuration).send(:reset)
  end

  context "6.1 - Tracking API" do
    context "Condition 6.1.1.1" do
      specify "The client MUST define a function for tracking with parameters: tracking event name (required), evaluation context (optional), and tracking event details (optional)" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(provider)
        client = OpenFeature::SDK.build_client

        expect(client).to respond_to(:track)

        # Verify the method accepts the required and optional parameters
        method = client.method(:track)
        params = method.parameters

        # First param is the required tracking event name
        expect(params).to include([:req, :tracking_event_name])
      end
    end

    context "Requirement 6.1.3" do
      specify "The evaluation context passed to the provider's track function MUST be merged in the order: API → client → invocation" do
        captured_context = nil

        tracking_provider = Class.new do
          def track(event_name, evaluation_context:, tracking_event_details:)
            # Capture for assertion
          end

          def metadata
            OpenFeature::SDK::Provider::ProviderMetadata.new(name: "tracking-provider")
          end
        end.new

        allow(tracking_provider).to receive(:track) do |event_name, evaluation_context:, tracking_event_details:|
          captured_context = evaluation_context
        end

        OpenFeature::SDK.configure do |config|
          config.evaluation_context = OpenFeature::SDK::EvaluationContext.new(api_key: "api_value", shared: "api")
        end
        OpenFeature::SDK.set_provider(tracking_provider)

        client = OpenFeature::SDK.build_client(
          evaluation_context: OpenFeature::SDK::EvaluationContext.new(client_key: "client_value", shared: "client")
        )

        invocation_context = OpenFeature::SDK::EvaluationContext.new(
          invocation_key: "invocation_value",
          shared: "invocation"
        )

        client.track("checkout", evaluation_context: invocation_context)

        expect(captured_context.field("api_key")).to eq("api_value")
        expect(captured_context.field("client_key")).to eq("client_value")
        expect(captured_context.field("invocation_key")).to eq("invocation_value")
        # Invocation has highest precedence
        expect(captured_context.field("shared")).to eq("invocation")
      end
    end

    context "Requirement 6.1.4" do
      specify "If the provider does not implement tracking, the client's track function MUST perform no operation" do
        # NoOpProvider does not implement track
        provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(provider)
        client = OpenFeature::SDK.build_client

        expect { client.track("event-name") }.not_to raise_error
      end

      specify "If the provider implements tracking, the track function is called" do
        track_called = false

        tracking_provider = Class.new do
          define_method(:track) do |event_name, evaluation_context:, tracking_event_details:|
            track_called = true
          end
        end.new

        OpenFeature::SDK.set_provider(tracking_provider)
        client = OpenFeature::SDK.build_client

        client.track("purchase")

        expect(track_called).to be true
      end
    end
  end

  context "6.2 - Tracking Event Details" do
    context "Requirement 6.2.1" do
      specify "The tracking event details MUST define an optional numeric value" do
        details = OpenFeature::SDK::TrackingEventDetails.new(value: 99.99)
        expect(details.value).to eq(99.99)
      end

      specify "The value defaults to nil when not provided" do
        details = OpenFeature::SDK::TrackingEventDetails.new
        expect(details.value).to be_nil
      end
    end

    context "Requirement 6.2.2" do
      specify "Tracking event details MUST support custom fields with string keys" do
        details = OpenFeature::SDK::TrackingEventDetails.new(
          value: 42,
          item: "premium-plan",
          quantity: 1,
          enabled: true
        )

        expect(details.fields["item"]).to eq("premium-plan")
        expect(details.fields["quantity"]).to eq(1)
        expect(details.fields["enabled"]).to be true
      end
    end

    specify "tracking event details are passed through to the provider" do
      captured_details = nil

      tracking_provider = Class.new do
        define_method(:track) do |event_name, evaluation_context:, tracking_event_details:|
          captured_details = tracking_event_details
        end
      end.new

      OpenFeature::SDK.set_provider(tracking_provider)
      client = OpenFeature::SDK.build_client

      details = OpenFeature::SDK::TrackingEventDetails.new(value: 19.99, plan: "enterprise")
      client.track("subscription", tracking_event_details: details)

      expect(captured_details).to be_a(OpenFeature::SDK::TrackingEventDetails)
      expect(captured_details.value).to eq(19.99)
      expect(captured_details.fields["plan"]).to eq("enterprise")
    end
  end
end
