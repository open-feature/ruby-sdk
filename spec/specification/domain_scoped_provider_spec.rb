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
    Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
      attr_reader :init_domain, :init_calls

      def initialize
        super
        @init_calls = 0
        @init_domain = :unset
      end

      def domain_scoped? = true

      def init(_evaluation_context = nil, domain: nil)
        @init_calls += 1
        @init_domain = domain
      end
    end
  end

  context "Requirements 1.1.2.2 and 2.4.1" do
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

  context "Requirement 1.1.8.1" do
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
      allow(provider).to receive(:init)

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")
      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-b")

      expect(OpenFeature::SDK.provider(domain: "domain-a")).to be(provider)
      expect(OpenFeature::SDK.provider(domain: "domain-b")).to be(provider)
      expect(provider).to have_received(:init).once
    end

    specify "rejects a domain-scoped provider whose domain_scoped? comes from an included module" do
      scoped = Module.new { def domain_scoped? = true }
      provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
        include scoped

        def init(_evaluation_context = nil, domain: nil) = nil
      end.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")

      expect do
        OpenFeature::SDK.set_provider(provider, domain: "domain-b")
      end.to raise_error(ArgumentError, /more than one domain/)
    end

    specify "evaluates domain_scoped? without holding the provider lock" do
      provider_mutex = configuration.instance_variable_get(:@provider_mutex)
      lock_held = nil
      provider = domain_scoped_test_provider_class.new
      provider.define_singleton_method(:domain_scoped?) do
        lock_held = provider_mutex.owned?
        true
      end

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")

      expect(lock_held).to be(false)
    end
  end

  context "Requirement 2.4.4" do
    after { configuration.logger = nil }

    specify "warns when a domain-scoped provider's init can't accept the domain" do
      logger = spy("Logger")
      configuration.logger = logger
      provider = domain_scoped_test_provider_class.new
      provider.define_singleton_method(:init) { |_evaluation_context = nil| @init_calls += 1 }

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain-a")

      expect(logger).to have_received(:warn).with(/domain-scoped.*domain/)
      expect(provider.init_calls).to eq(1)
    end
  end

  context "legacy init compatibility" do
    specify "initializes a legacy single-argument init provider bound to a domain without passing the domain" do
      provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
        attr_reader :init_calls, :last_context

        def init(evaluation_context = nil)
          @init_calls = (@init_calls || 0) + 1
          @last_context = evaluation_context
        end
      end.new

      OpenFeature::SDK.set_provider_and_wait(provider, domain: "test-domain")

      expect(provider.init_calls).to eq(1)
      expect(provider.last_context).to eq(OpenFeature::SDK.evaluation_context)
      expect(configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
    end

    specify "does not retry init when a domain-aware provider raises" do
      provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
        attr_reader :call_count

        def init(_evaluation_context = nil, domain: nil)
          @call_count = (@call_count || 0) + 1
          raise TypeError, "configuration error"
        end
      end.new

      expect do
        OpenFeature::SDK.set_provider_and_wait(provider, domain: "domain")
      end.to raise_error(OpenFeature::SDK::ProviderInitializationError)

      expect(provider.call_count).to eq(1)
    end
  end
end
