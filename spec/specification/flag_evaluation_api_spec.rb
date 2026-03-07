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

        OpenFeature::SDK.set_provider_and_wait(provider)
      end
    end

    context "Requirement 1.1.2.2" do
      specify "provider instances already active need not be initialized again" do
        shared_provider = OpenFeature::SDK::Provider::InMemoryProvider.new

        expect(shared_provider).to receive(:init).once

        OpenFeature::SDK.set_provider_and_wait(shared_provider, domain: "domain-a")
        OpenFeature::SDK.set_provider_and_wait(shared_provider, domain: "domain-b")
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

      specify "provider bound to multiple domains is not shut down until the last binding is removed" do
        shared_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        replacement = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider_and_wait(shared_provider, domain: "domain-a")
        OpenFeature::SDK.set_provider_and_wait(shared_provider, domain: "domain-b")

        # Replace in one domain — should NOT shut down since still bound to "domain-b"
        expect(shared_provider).not_to receive(:shutdown)
        OpenFeature::SDK.set_provider_and_wait(replacement, domain: "domain-a")
      end

      specify "provider is shut down when the last binding is removed" do
        shared_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        replacement_a = OpenFeature::SDK::Provider::InMemoryProvider.new
        replacement_b = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider_and_wait(shared_provider, domain: "domain-a")
        OpenFeature::SDK.set_provider_and_wait(shared_provider, domain: "domain-b")

        # Replace first binding — no shutdown
        OpenFeature::SDK.set_provider_and_wait(replacement_a, domain: "domain-a")

        # Replace last binding — shutdown
        expect(shared_provider).to receive(:shutdown)
        OpenFeature::SDK.set_provider_and_wait(replacement_b, domain: "domain-b")
      end
    end

    context "Requirement 1.1.2.4" do
      specify "The API SHOULD provide functions to set a provider and wait for the initialize function to complete or abnormally terminate" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new

        # set_provider_and_wait should exist
        expect(OpenFeature::SDK).to respond_to(:set_provider_and_wait)

        # It should block until initialization completes
        allow(provider).to receive(:init) do
          sleep(0.1)  # Simulate initialization time
        end

        start_time = Time.now
        OpenFeature::SDK.set_provider_and_wait(provider)
        elapsed = Time.now - start_time

        expect(elapsed).to be >= 0.1
        expect(OpenFeature::SDK.provider).to be(provider)
      end

      specify "set_provider_and_wait must handle initialization errors" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        error_message = "Initialization failed"

        allow(provider).to receive(:init).and_raise(StandardError.new(error_message))

        expect {
          OpenFeature::SDK.set_provider_and_wait(provider)
        }.to raise_error(OpenFeature::SDK::ProviderInitializationError) do |error|
          expect(error.message).to include(error_message)
        end
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
      before(:each) do
        OpenFeature::SDK.hooks.clear
      end

      specify "The API must provide a function to add hooks which accepts one or more API-conformant hooks, and appends them to the collection of any previously added hooks." do
        hook1 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        hook2 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new

        OpenFeature::SDK.hooks << hook1
        OpenFeature::SDK.hooks << hook2

        expect(OpenFeature::SDK.hooks).to eq([hook1, hook2])
      end

      specify "When new hooks are added, previously added hooks are not removed." do
        hook1 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        OpenFeature::SDK.hooks << hook1

        hook2 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        OpenFeature::SDK.hooks << hook2

        expect(OpenFeature::SDK.hooks).to include(hook1)
        expect(OpenFeature::SDK.hooks).to include(hook2)
        expect(OpenFeature::SDK.hooks.size).to eq(2)
      end

      specify "The API provides an add_hooks method that appends to existing hooks." do
        hook1 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        hook2 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        hook3 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new

        OpenFeature::SDK.add_hooks(hook1)
        OpenFeature::SDK.add_hooks(hook2, hook3)

        expect(OpenFeature::SDK.hooks).to eq([hook1, hook2, hook3])
      end
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
  end

  context "1.2 - Client Usage" do
    context "Requirement 1.2.1" do
      specify "The client MUST provide a method to add hooks which accepts one or more API-conformant hooks, and appends them to the collection of any previously added hooks. When new hooks are added, previously added hooks are not removed." do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(provider)
        client = OpenFeature::SDK.build_client

        hook1 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        hook2 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new

        client.hooks << hook1
        client.hooks << hook2

        expect(client.hooks).to eq([hook1, hook2])
        expect(client.hooks).to include(hook1)
      end

      specify "The client provides an add_hooks method that appends to existing hooks." do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(provider)
        client = OpenFeature::SDK.build_client

        hook1 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        hook2 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        hook3 = Class.new { include OpenFeature::SDK::Hooks::Hook }.new

        client.add_hooks(hook1)
        client.add_hooks(hook2, hook3)

        expect(client.hooks).to eq([hook1, hook2, hook3])
      end
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

      specify "name SHOULD be an alias to domain for backward compatibility." do
        client = OpenFeature::SDK.build_client(domain: "my-domain")
        expect(client.metadata.name).to eq("my-domain")
        expect(client.metadata.name).to eq(client.metadata.domain)
      end
    end
  end

  context "1.4 - Flag Metadata" do
    context "Requirement 1.4.14" do
      specify "flag_metadata defaults to an empty hash when not provided" do
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: true)
        expect(resolution.flag_metadata).to eq({})
      end

      specify "flag_metadata defaults to an empty hash when explicitly set to nil" do
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: true, flag_metadata: nil)
        expect(resolution.flag_metadata).to eq({})
      end

      specify "flag_metadata preserves provided values" do
        metadata = {"scope" => "user", "version" => 2}
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: true, flag_metadata: metadata)
        expect(resolution.flag_metadata).to eq({"scope" => "user", "version" => 2})
      end

      specify "flag_metadata defaults correctly through client evaluation" do
        provider = OpenFeature::SDK::Provider::NoOpProvider.new
        OpenFeature::SDK.set_provider(provider)
        client = OpenFeature::SDK.build_client

        details = client.fetch_boolean_details(flag_key: "test", default_value: false)
        expect(details.flag_metadata).to eq({})
      end
    end

    context "Requirement 1.4.15.1" do
      specify "flag_metadata is frozen when not provided" do
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: true)
        expect(resolution.flag_metadata).to be_frozen
      end

      specify "flag_metadata is frozen when provided" do
        metadata = {"scope" => "user"}
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: true, flag_metadata: metadata)
        expect(resolution.flag_metadata).to be_frozen
      end

      specify "flag_metadata cannot be mutated" do
        metadata = {"scope" => "user"}
        resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: true, flag_metadata: metadata)
        expect { resolution.flag_metadata["new_key"] = "value" }.to raise_error(FrozenError)
      end
    end
  end

  context "1.6 - Shutdown" do
    context "Requirement 1.6.1" do
      specify "The API MUST define a mechanism to propagate a shutdown request to registered providers." do
        expect(OpenFeature::SDK).to respond_to(:shutdown)
      end
    end

    context "Requirement 1.6.2" do
      specify "When a shutdown function is called, the API invokes the shutdown function on the registered provider." do
        provider1 = OpenFeature::SDK::Provider::InMemoryProvider.new
        provider2 = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider_and_wait(provider1)
        OpenFeature::SDK.set_provider_and_wait(provider2, domain: "test-domain")

        expect(provider1).to receive(:shutdown)
        expect(provider2).to receive(:shutdown)

        OpenFeature::SDK.shutdown
      end

      specify "After shutdown, providers are cleared." do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)

        OpenFeature::SDK.shutdown

        expect(OpenFeature::SDK.provider).to be_nil
      end
    end
  end

  context "1.7 - Provider Status" do
    context "Requirement 1.7.1" do
      specify "The client MUST define a provider status accessor which indicates the readiness of the associated provider." do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)
        client = OpenFeature::SDK.build_client

        expect(client).to respond_to(:provider_status)
        expect(client.provider_status).to eq(OpenFeature::SDK::ProviderState::READY)
      end
    end

    context "Requirement 1.7.6" do
      specify "If the provider status is NOT_READY, the client should return the default value with PROVIDER_NOT_READY error." do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)
        client = OpenFeature::SDK.build_client

        allow(OpenFeature::SDK.configuration).to receive(:provider_state).with(provider).and_return(OpenFeature::SDK::ProviderState::NOT_READY)

        result = client.fetch_boolean_details(flag_key: "flag", default_value: false)

        expect(result.value).to eq(false)
        expect(result.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::PROVIDER_NOT_READY)
        expect(result.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end

      specify "error hooks and finally hooks MUST run when short-circuiting due to NOT_READY" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)
        client = OpenFeature::SDK.build_client

        allow(OpenFeature::SDK.configuration).to receive(:provider_state).with(provider).and_return(OpenFeature::SDK::ProviderState::NOT_READY)

        call_log = []

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            call_log << "error"
          end

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            call_log << "finally"
          end
        end.new

        client.fetch_boolean_value(flag_key: "flag", default_value: false, hooks: [hook])

        expect(call_log).to include("error", "finally")
      end
    end

    context "Requirement 1.7.7" do
      specify "If the provider status is FATAL, the client should return the default value with PROVIDER_FATAL error." do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)
        client = OpenFeature::SDK.build_client

        allow(OpenFeature::SDK.configuration).to receive(:provider_state).with(provider).and_return(OpenFeature::SDK::ProviderState::FATAL)

        result = client.fetch_string_details(flag_key: "flag", default_value: "default")

        expect(result.value).to eq("default")
        expect(result.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::PROVIDER_FATAL)
        expect(result.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end

      specify "error hooks and finally hooks MUST run when short-circuiting due to FATAL" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)
        client = OpenFeature::SDK.build_client

        allow(OpenFeature::SDK.configuration).to receive(:provider_state).with(provider).and_return(OpenFeature::SDK::ProviderState::FATAL)

        call_log = []

        hook = Class.new do
          include OpenFeature::SDK::Hooks::Hook

          define_method(:error) do |hook_context:, exception:, hints:|
            call_log << "error"
          end

          define_method(:finally) do |hook_context:, evaluation_details:, hints:|
            call_log << "finally"
          end
        end.new

        client.fetch_string_value(flag_key: "flag", default_value: "default", hooks: [hook])

        expect(call_log).to include("error", "finally")
      end
    end
  end

  context "Logger Methods" do
    specify "delegates logger getter to configuration" do
      logger = double("Logger")
      allow(OpenFeature::SDK::API.instance.configuration).to receive(:logger).and_return(logger)

      expect(OpenFeature::SDK::API.instance.logger).to eq(logger)
    end

    specify "delegates logger setter to configuration" do
      logger = double("Logger")
      expect(OpenFeature::SDK::API.instance.configuration).to receive(:logger=).with(logger)

      OpenFeature::SDK::API.instance.logger = logger
    end
  end
end
