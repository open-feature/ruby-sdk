# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Domain-scoped provider binding" do
  before do
    OpenFeature::SDK.configure do |config|
      config.evaluation_context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "user")
    end
  end

  after do
    OpenFeature::SDK.shutdown
  end

  let(:domain_scoped_test_provider_class) do
    Class.new do
      attr_reader :init_domain, :init_calls

      def initialize
        @metadata = OpenFeature::SDK::Provider::ProviderMetadata.new(name: "domain-scoped-test")
        @init_calls = 0
        @init_domain = :unset
      end

      attr_reader :metadata

      def domain_scoped?
        true
      end

      def init(_evaluation_context = nil, domain: nil)
        @init_calls += 1
        @init_domain = domain
      end

      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
      end

      def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
      end

      def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
      end

      def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
      end

      def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
      end

      def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
        OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
      end
    end
  end

  context "Requirement 2.4.1" do
    specify "the provider mutator passes the bound domain to init for a named provider" do
      provider = domain_scoped_test_provider_class.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "my-domain")

      expect(provider.init_domain).to eq("my-domain")
    end

    specify "the provider mutator passes nil domain to init for the default provider" do
      provider = domain_scoped_test_provider_class.new

      OpenFeature::SDK.set_provider_and_wait(provider)

      expect(provider.init_domain).to be_nil
    end
  end

  let(:configuration) { OpenFeature::SDK::API.instance.configuration }

  context "Condition 1.1.8" do
    specify "the provider mutator MUST NOT bind a domain-scoped provider to a second named domain" do
      provider = domain_scoped_test_provider_class.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")

      expect do
        OpenFeature::SDK.set_provider(provider, domain: "domain-b")
      end.to raise_error(ArgumentError, "Cannot bind domain-scoped provider to more than one domain")

      expect(configuration.provider(domain: "domain-a")).to be(provider)
      expect(configuration.instance_variable_get(:@providers)["domain-b"]).to be_nil
    end

    specify "the provider mutator MUST NOT bind a domain-scoped named provider as the default provider" do
      provider = domain_scoped_test_provider_class.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")

      expect do
        OpenFeature::SDK.set_provider(provider)
      end.to raise_error(ArgumentError, "Cannot bind domain-scoped provider to more than one domain")

      expect(configuration.provider(domain: "domain-a")).to be(provider)
      expect(configuration.instance_variable_get(:@providers)[nil]).not_to be(provider)
    end

    specify "the provider mutator MUST NOT bind a domain-scoped default provider to a named domain" do
      provider = domain_scoped_test_provider_class.new

      OpenFeature::SDK.set_provider_and_wait(provider)

      expect do
        OpenFeature::SDK.set_provider(provider, domain: "domain-a")
      end.to raise_error(ArgumentError, "Cannot bind domain-scoped provider to more than one domain")

      expect(configuration.provider).to be(provider)
      expect(configuration.instance_variable_get(:@providers)["domain-a"]).to be_nil
    end

    specify "allows rebinding the same domain-scoped provider instance to the same named domain" do
      provider = domain_scoped_test_provider_class.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")
      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")

      expect(provider.init_calls).to eq(1)
      expect(provider.init_domain).to eq("domain-a")
    end

    specify "allows rebinding the same domain-scoped provider instance as the default provider" do
      provider = domain_scoped_test_provider_class.new

      OpenFeature::SDK.set_provider_and_wait(provider)
      OpenFeature::SDK.set_provider_and_wait(provider)

      expect(provider.init_calls).to eq(1)
      expect(provider.init_domain).to be_nil
    end

    specify "allows a non-domain-scoped provider to back multiple domains" do
      provider = OpenFeature::SDK::Provider::InMemoryProvider.new
      allow(provider).to receive(:init).and_call_original

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")
      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-b")

      expect(OpenFeature::SDK.provider(domain: "domain-a")).to be(provider)
      expect(OpenFeature::SDK.provider(domain: "domain-b")).to be(provider)
      expect(provider).to have_received(:init).once
    end
  end

  context "legacy init compatibility" do
    specify "initializes legacy single-argument init providers when bound to a domain" do
      provider = OpenFeature::SDK::LegacyInitProvider.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "test-domain")

      expect(provider.init_calls).to eq(1)
      expect(provider.last_context).to eq(OpenFeature::SDK.evaluation_context)
      expect(configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end

    specify "does not pass domain to legacy init providers" do
      provider = OpenFeature::SDK::LegacyInitProvider.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "test-domain")

      expect(provider.init_calls).to eq(1)
      expect(provider.last_context).to eq(OpenFeature::SDK.evaluation_context)
    end

    specify "does not retry init when a domain-aware provider raises" do
      broken_provider_class = Class.new do
        attr_reader :call_count

        def initialize
          @metadata = OpenFeature::SDK::Provider::ProviderMetadata.new(name: "broken")
          @call_count = 0
        end

        attr_reader :metadata

        def init(_evaluation_context = nil, domain: nil)
          @call_count += 1
          raise TypeError, "configuration error"
        end

        def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
          OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
        end

        def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
          OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
        end

        def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
          OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
        end

        def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
          OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
        end

        def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
          OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
        end

        def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
          OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
        end
      end

      provider = broken_provider_class.new

      expect do
        OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain")
      end.to raise_error(OpenFeature::SDK::ProviderInitializationError)

      expect(provider.call_count).to eq(1)
    end
  end
end
