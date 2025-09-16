# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Flag Evaluation API" do
  context "1.1 - API Initialization and Configuration" do
    context "Requirement 1.1.1" do
      specify "the API should exist as a global singleton" do
        expect(OpenFeature::SDK::API).to include(Singleton)
      end
    end

    context "Requirement 1.1.2.1" do
      specify "the API must define a provider mutator" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new

        OpenFeature::SDK.set_provider(provider)

        expect(OpenFeature::SDK.provider).to be(provider)
      end
    end

    context "Requirement 1.1.2.2" do
      specify "the provider mutator must invoke an initialize function on the provider" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        expect(provider).to receive(:init)

        OpenFeature::SDK.set_provider(provider)
      end
    end

    context "Requirement 1.1.2.3" do
      specify "the provider mutator must invoke a shutdown function on previously registered provider" do
        previous_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        new_provider = OpenFeature::SDK::Provider::InMemoryProvider.new

        expect(previous_provider).to receive(:shutdown)
        expect(new_provider).not_to receive(:shutdown)

        OpenFeature::SDK.set_provider(previous_provider)
        OpenFeature::SDK.set_provider(new_provider)
      end
    end

    context "Requirement 1.1.3" do
      specify "the API must provide a function to bind a given provider to one or more client domains" do
        first_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        second_provider = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider(first_provider, domain: "first")
        OpenFeature::SDK.set_provider(second_provider, domain: "second")

        expect(OpenFeature::SDK.provider(domain: "first")).to be(first_provider)
        expect(OpenFeature::SDK.provider(domain: "second")).to be(second_provider)
      end

      specify "if client domain is already bound, it is overwritten" do
        previous_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        new_provider = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider(previous_provider, domain: "testing")
        expect(OpenFeature::SDK.provider(domain: "testing")).to be(previous_provider)

        OpenFeature::SDK.set_provider(new_provider, domain: "testing")
        expect(OpenFeature::SDK.provider(domain: "testing")).to be(new_provider)
      end
    end

    context "Requirement 1.1.4" do
      pending "The API must provide a function to add hooks which accepts one or more API-conformant hooks, and appends them to the collection of any previously added hooks."

      pending "When new hooks are added, previously added hooks are not removed."
    end

    context "Requirement 1.1.5" do
      before do
        default_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider(default_provider)

        domain_1_provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(domain_1_provider, domain: "domain_1")
      end

      specify "The API MUST provide a function for retrieving the metadata field of the configured provider." do
        expect(OpenFeature::SDK.provider.metadata.name).to eq("In-memory Provider")
      end

      specify "It's possible to access provider metadata using a domain." do
        expect(OpenFeature::SDK.provider(domain: "domain_1").metadata.name).to eq("No-op Provider")
      end

      specify "If a provider has not be registered under the requested domain, the default provider metadata is returned." do
        expect(OpenFeature::SDK.provider(domain: "not_here").metadata.name).to eq("In-memory Provider")
      end
    end

    context "Requirement 1.1.6" do
      before do
        default_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider(default_provider)

        domain_1_provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(domain_1_provider, domain: "domain_1")
      end

      specify "The API MUST provide a function for creating a client" do
        client = OpenFeature::SDK.build_client

        expect(client.instance_variable_get(:@provider).metadata.name).to eq("In-memory Provider")
      end

      specify "which accepts domain as an optional parameter." do
        client = OpenFeature::SDK.build_client(domain: "domain_1")

        expect(client.instance_variable_get(:@provider).metadata.name).to eq("No-op Provider")
      end
    end

    context "Requirement 1.1.7" do
      specify "The client creation function MUST NOT throw, or otherwise abnormally terminate." do
        expect_any_instance_of(OpenFeature::SDK::Configuration).to receive(:provider).and_raise(StandardError)

        expect do
          client = OpenFeature::SDK.build_client

          expect(client.instance_variable_get(:@provider).metadata.name).to eq("No-op Provider")
        end.not_to raise_error
      end
    end

    context "Shutdown functionality" do
      specify "The API must provide a shutdown function to gracefully clean up all providers" do
        provider1 = OpenFeature::SDK::Provider::InMemoryProvider.new
        provider2 = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider(provider1)
        OpenFeature::SDK.set_provider(provider2, domain: "testing")

        expect(provider1).to receive(:shutdown)
        expect(provider2).to receive(:shutdown)

        expect { OpenFeature::SDK.shutdown }.not_to raise_error
      end

      specify "Shutdown does not raise errors when providers don't have shutdown methods" do
        provider_without_shutdown = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(provider_without_shutdown)

        expect { OpenFeature::SDK.shutdown }.not_to raise_error
      end
    end
  end

  context "1.2 - Client Usage" do
    context "Requirement 1.2.1" do
      pending "The client MUST provide a method to add hooks which accepts one or more API-conformant hooks, and appends them to the collection of any previously added hooks. When new hooks are added, previously added hooks are not removed."
    end

    context "Requirement 1.2.2" do
      before do
        default_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider(default_provider)

        domain_1_provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(domain_1_provider, domain: "domain_1")
      end

      specify "The client interface MUST define a metadata member or accessor, containing an immutable domain field or accessor of type string, which corresponds to the domain value supplied during client creation." do
        client = OpenFeature::SDK.build_client
        expect(client.metadata.domain).to be_nil

        client = OpenFeature::SDK.build_client(domain: "domain_1")
        expect(client.metadata.domain).to eq("domain_1")
      end
    end
  end
end
