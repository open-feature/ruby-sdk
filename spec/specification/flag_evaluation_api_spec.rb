# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Flag Evaluation API" do
  # An InMemoryProvider whose init blocks until something is pushed onto +gate+.
  def slow_init_provider(gate)
    Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
      define_method(:init) { |_evaluation_context = nil| gate.pop }

      def metadata = OpenFeature::SDK::Provider::ProviderMetadata.new(name: "Slow Provider")
    end.new
  end

  # Collects threads the SDK starts (e.g. async init) so a test can join them.
  def capture_threads
    [].tap do |threads|
      allow(Thread).to receive(:new).and_wrap_original { |original, *args, &block| original.call(*args, &block).tap { |t| threads << t } }
    end
  end

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

    context "Requirement 1.1.2.3: replaced providers are detached" do
      before { OpenFeature::SDK.configuration.send(:reset) }
      after { OpenFeature::SDK.configuration.send(:reset) }

      specify "a replaced provider's events no longer reach handlers" do
        old = OpenFeature::SDK::Provider::InMemoryProvider.new
        received = []
        OpenFeature::SDK.set_provider_and_wait(old)
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, ->(details) { received << details })

        OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new)
        old.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

        expect(received).to be_empty
        expect(old.configuration_attached?).to be(false)
        expect(OpenFeature::SDK.configuration.provider_tracked?(old)).to be(false)
      end

      specify "a provider still bound to another domain stays attached" do
        shared = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(shared, domain: "a")
        OpenFeature::SDK.set_provider_and_wait(shared, domain: "b")

        OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new, domain: "a")

        expect(shared.configuration_attached?).to be(true)
      end

      specify "re-setting the same provider on the same domain keeps it attached" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)

        OpenFeature::SDK.set_provider_and_wait(provider)

        expect(provider.configuration_attached?).to be(true)
      end

      specify "an async init that finishes after replacement is ignored" do
        gate = Queue.new
        slow = slow_init_provider(gate)
        threads = capture_threads
        ready_names = []
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(details) { ready_names << details[:provider_name] })

        OpenFeature::SDK.set_provider(slow)
        OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new)
        gate << :go
        threads.each(&:join)

        expect(OpenFeature::SDK.configuration.provider_tracked?(slow)).to be(false)
        expect(ready_names).to eq(["In-memory Provider"])
      end

      specify "an event racing with replacement does not re-track the replaced provider" do
        old = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(old)
        registry = OpenFeature::SDK.configuration.instance_variable_get(:@provider_state_registry)
        checked = Queue.new
        resume = Queue.new
        # Pause the event thread after its binding check, before it writes the state
        allow(registry).to receive(:update_state_from_event).and_wrap_original do |original, provider, *args|
          if provider.equal?(old)
            checked << true
            resume.pop
          end
          original.call(provider, *args)
        end

        emitter = Thread.new { old.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE) }
        checked.pop
        replacer = Thread.new { OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new) }
        # Unsynchronized, replacement finishes here; synchronized, it waits for the event
        replacer.join(0.2)
        resume << :go

        expect([emitter, replacer].map { |t| t.join(5) }).to all(be_a(Thread))
        expect(OpenFeature::SDK.configuration.provider_tracked?(old)).to be(false)
      end

      specify "replacing a NoOpProvider does not raise" do
        OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::NoOpProvider.new)

        expect { OpenFeature::SDK.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new) }.not_to raise_error
      end
    end

    context "Requirement 1.1.2.2: init outcome" do
      before { OpenFeature::SDK.configuration.send(:reset) }
      after { OpenFeature::SDK.configuration.send(:reset) }

      let(:outcomes) { Queue.new }
      let(:aborted_error) { Class.new(Exception) } # rubocop:disable Lint/InheritException
      # Each init blocks until an outcome is pushed; :fail raises, :abort raises a non-StandardError
      let(:provider) do
        queue = outcomes
        aborted = aborted_error
        Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
          attr_reader :init_calls

          define_method(:init) do |_evaluation_context = nil|
            @init_calls = (@init_calls || 0) + 1
            outcome = queue.pop
            raise "init failed" if outcome == :fail
            raise aborted if outcome == :abort
          end
        end.new
      end

      # Blocks until a set_provider_and_wait is waiting on the provider's running init
      def wait_for_waiter(provider)
        attempt = OpenFeature::SDK.configuration.instance_variable_get(:@init_attempts)[provider]
        200.times do
          break if attempt.done.num_waiting.positive?
          sleep 0.01
        end
      end

      # A thread already waiting on the running init; its value is the error it raised, if any
      def start_waiter(domain)
        waiter = background do
          OpenFeature::SDK.set_provider_and_wait(provider, domain:)
        rescue OpenFeature::SDK::ProviderInitializationError => e
          e
        end
        wait_for_waiter(provider)
        waiter
      end

      specify "a provider whose init failed is initialized again when set again" do
        outcomes << :fail << :ok

        expect { OpenFeature::SDK.set_provider_and_wait(provider) }.to raise_error(OpenFeature::SDK::ProviderInitializationError)
        OpenFeature::SDK.set_provider_and_wait(provider)

        expect(provider.init_calls).to eq(2)
        expect(OpenFeature::SDK.configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "a provider whose init failed is initialized again when bound to another domain" do
        outcomes << :fail << :ok

        expect { OpenFeature::SDK.set_provider_and_wait(provider, domain: "a") }.to raise_error(OpenFeature::SDK::ProviderInitializationError)
        OpenFeature::SDK.set_provider_and_wait(provider, domain: "b")

        expect(provider.init_calls).to eq(2)
      end

      specify "binding another domain while init is running starts no second init" do
        threads = capture_threads

        OpenFeature::SDK.set_provider(provider, domain: "a")
        OpenFeature::SDK.set_provider(provider, domain: "b")
        outcomes << :ok << :ok
        threads.each { |t| t.join(5) }

        expect(provider.init_calls).to eq(1)
      end

      specify "set_provider_and_wait waits for an init that's already running" do
        OpenFeature::SDK.set_provider(provider, domain: "a")
        waiter = start_waiter("b")

        outcomes << :ok << :ok

        expect(waiter.join(5)).to be(waiter)
        expect(provider.init_calls).to eq(1)
        expect(OpenFeature::SDK.configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "set_provider_and_wait raises when the running init it waited for fails" do
        OpenFeature::SDK.set_provider(provider, domain: "a")
        waiter = start_waiter("b")

        outcomes << :fail << :ok

        expect(waiter.join(5)&.value).to be_a(OpenFeature::SDK::ProviderInitializationError)
        expect(provider.init_calls).to eq(1)
      end

      specify "a provider that reported ERROR after a successful init isn't initialized again" do
        outcomes << :ok << :ok
        OpenFeature::SDK.set_provider_and_wait(provider, domain: "a")
        provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, message: "lost connection")

        OpenFeature::SDK.set_provider_and_wait(provider, domain: "b")

        expect(provider.init_calls).to eq(1)
      end

      specify "a provider set again after shutdown interrupted its init is initialized again" do
        threads = capture_threads
        OpenFeature::SDK.set_provider(provider)
        OpenFeature::SDK.shutdown
        outcomes << :ok
        threads.each { |t| t.join(5) }
        outcomes << :ok

        OpenFeature::SDK.set_provider_and_wait(provider)

        expect(provider.init_calls).to eq(2)
      end

      specify "a READY handler can bind the same provider to another domain" do
        outcomes << :ok
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, lambda do |_|
          next if OpenFeature::SDK.provider(domain: "b").equal?(provider)

          OpenFeature::SDK.set_provider_and_wait(provider, domain: "b")
        end)

        setter = Thread.new { OpenFeature::SDK.set_provider_and_wait(provider, domain: "a") }

        expect(setter.join(2)).to be(setter)
        expect(OpenFeature::SDK.configuration.instance_variable_get(:@providers)["b"]).to be(provider)
      end

      specify "an ERROR handler can retry a failed init" do
        outcomes << :fail << :ok
        retried = false
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_ERROR, lambda do |_|
          next if retried

          retried = true
          OpenFeature::SDK.set_provider_and_wait(provider)
        end)

        setter = Thread.new do
          OpenFeature::SDK.set_provider_and_wait(provider)
        rescue OpenFeature::SDK::ProviderInitializationError
          :raised
        end

        expect(setter.join(2)&.value).to eq(:raised)
        expect(provider.init_calls).to eq(2)
        expect(OpenFeature::SDK.configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "an exception before init starts leaves the provider able to initialize" do
        error_class = aborted_error
        old = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) { define_method(:shutdown) { raise error_class } }.new
        OpenFeature::SDK.set_provider_and_wait(old)

        expect { OpenFeature::SDK.set_provider_and_wait(provider) }.to raise_error(error_class)
        outcomes << :ok
        setter = Thread.new { OpenFeature::SDK.set_provider_and_wait(provider) }

        expect(setter.join(2)).to be(setter)
        expect(provider.init_calls).to eq(1)
        expect(OpenFeature::SDK.configuration.provider_state(provider)).to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "a waiter raises when the init it waited for was stopped by a non-StandardError" do
        threads = capture_threads
        OpenFeature::SDK.set_provider(provider, domain: "a")
        waiter = start_waiter("b")
        threads.each { |t| t.report_on_exception = false }

        outcomes << :abort

        expect(waiter.join(2)&.value).to be_a(OpenFeature::SDK::ProviderInitializationError)
        expect(OpenFeature::SDK.configuration.provider_state(provider)).not_to eq(OpenFeature::SDK::ProviderState::READY)
      end

      specify "shutdown releases a waiter whose init hasn't finished" do
        OpenFeature::SDK.set_provider(provider, domain: "a")
        waiter = start_waiter("b")

        OpenFeature::SDK.shutdown

        expect(waiter.join(2)&.value).to be_a(OpenFeature::SDK::ProviderInitializationError)
      ensure
        outcomes << :ok
      end

      specify "replacing a provider releases a waiter on its unfinished init" do
        OpenFeature::SDK.set_provider(provider, domain: "a")
        waiter = start_waiter("a")

        OpenFeature::SDK.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new, domain: "a")

        expect(waiter.join(2)&.value).to be_a(OpenFeature::SDK::ProviderInitializationError)
      ensure
        outcomes << :ok
      end

      specify "replacing a provider while set_provider_and_wait runs its init makes that call raise too" do
        initiator = background do
          OpenFeature::SDK.set_provider_and_wait(provider, domain: "a")
        rescue OpenFeature::SDK::ProviderInitializationError => e
          e
        end
        200.times do
          break if outcomes.num_waiting.positive?
          sleep 0.01
        end

        OpenFeature::SDK.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new, domain: "a")
        outcomes << :ok

        expect(initiator.join(2)&.value).to be_a(OpenFeature::SDK::ProviderInitializationError)
        expect(OpenFeature::SDK.configuration.provider_tracked?(provider)).to be(false)
      end

      specify "set_provider_and_wait from inside the provider's own init raises instead of deadlocking" do
        emitting = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
          def init(_evaluation_context = nil) = emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)
        end.new
        reentry = nil
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, lambda do |_|
          OpenFeature::SDK.set_provider_and_wait(emitting)
        rescue OpenFeature::SDK::ProviderInitializationError => e
          reentry = e
        end)

        setter = background { OpenFeature::SDK.set_provider_and_wait(emitting) }

        expect(setter.join(2)).to be(setter)
        expect(reentry).to be_a(OpenFeature::SDK::ProviderInitializationError)
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
      after { OpenFeature::SDK.configuration.send(:reset) }

      specify "When a shutdown function is called, the API invokes the shutdown function on the registered provider." do
        provider1 = OpenFeature::SDK::Provider::InMemoryProvider.new
        provider2 = OpenFeature::SDK::Provider::InMemoryProvider.new

        OpenFeature::SDK.set_provider_and_wait(provider1)
        OpenFeature::SDK.set_provider_and_wait(provider2, domain: "test-domain")

        expect(provider1).to receive(:shutdown)
        expect(provider2).to receive(:shutdown)

        OpenFeature::SDK.shutdown
      end

      specify "After shutdown, providers are detached and their events are ignored" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)
        OpenFeature::SDK.shutdown
        received = []
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, ->(details) { received << details })

        provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

        expect(received).to be_empty
        expect(provider.configuration_attached?).to be(false)
        expect(OpenFeature::SDK.configuration.provider_tracked?(provider)).to be(false)
      end

      specify "After shutdown, an async init that finishes late is ignored" do
        gate = Queue.new
        slow = slow_init_provider(gate)
        threads = capture_threads

        OpenFeature::SDK.set_provider(slow)
        OpenFeature::SDK.shutdown
        received = []
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(details) { received << details })
        gate << :go
        threads.each(&:join)

        expect(OpenFeature::SDK.configuration.provider_tracked?(slow)).to be(false)
        expect(received).to be_empty
      end

      specify "During shutdown, an async init that finishes is ignored" do
        gate = Queue.new
        slow = slow_init_provider(gate)
        threads = capture_threads
        state_during_shutdown = nil
        slow.define_singleton_method(:shutdown) do
          gate << :go
          threads.each { |t| t.join(5) }
          state_during_shutdown = OpenFeature::SDK.configuration.provider_state(self)
        end
        ready_names = []

        OpenFeature::SDK.set_provider(slow)
        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ->(details) { ready_names << details[:provider_name] })
        OpenFeature::SDK.shutdown

        expect(state_during_shutdown).to eq(OpenFeature::SDK::ProviderState::NOT_READY)
        expect(ready_names).not_to include("Slow Provider")
      end

      specify "After shutdown, providers are cleared." do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)

        OpenFeature::SDK.shutdown

        expect(OpenFeature::SDK.provider).to be_nil
      end

      specify "After shutdown, hooks are cleared." do
        hook = Class.new { include OpenFeature::SDK::Hooks::Hook }.new
        OpenFeature::SDK.add_hooks(hook)
        expect(OpenFeature::SDK.hooks).not_to be_empty

        OpenFeature::SDK.shutdown

        expect(OpenFeature::SDK.hooks).to be_empty
      end

      specify "After shutdown, evaluation context is cleared." do
        OpenFeature::SDK.configure do |config|
          config.evaluation_context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-1")
        end
        expect(OpenFeature::SDK.evaluation_context).not_to be_nil

        OpenFeature::SDK.shutdown

        expect(OpenFeature::SDK.evaluation_context).to be_nil
      end

      specify "After shutdown, transaction context propagator is cleared." do
        propagator = OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new
        OpenFeature::SDK.set_transaction_context_propagator(propagator)
        expect(OpenFeature::SDK.configuration.transaction_context_propagator).not_to be_nil

        OpenFeature::SDK.shutdown

        expect(OpenFeature::SDK.configuration.transaction_context_propagator).to be_nil
      end
    end
  end

  context "1.4 - Flag Evaluation" do
    context "Requirement 1.4.10" do
      specify "client must not throw exceptions even when no hooks are registered and provider raises" do
        error_provider = Class.new do
          def metadata
            OpenFeature::SDK::Provider::ProviderMetadata.new(name: "Error Provider")
          end

          def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
            raise "provider internal error"
          end

          def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
            raise "provider internal error"
          end

          def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
            raise "provider internal error"
          end

          def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
            raise "provider internal error"
          end

          def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
            raise "provider internal error"
          end

          def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
            raise "provider internal error"
          end
        end.new

        OpenFeature::SDK.set_provider_and_wait(error_provider)
        client = OpenFeature::SDK.build_client

        # Ensure no hooks are registered (fast path)
        OpenFeature::SDK.hooks.clear

        result = nil
        expect {
          result = client.fetch_boolean_details(flag_key: "flag", default_value: false)
        }.not_to raise_error

        expect(result.value).to eq(false)
        expect(result.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        expect(result.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
      end

      context "abnormal execution returns the default value" do
        let(:logger) { spy("Logger") }
        let(:hook) { Class.new { include OpenFeature::SDK::Hooks::Hook }.new }
        let(:in_memory) { OpenFeature::SDK::Provider::InMemoryProvider.new("flag" => true) }

        def resolving_provider(resolution)
          Class.new do
            define_method(:fetch_boolean_value) { |**| resolution }
          end.new
        end

        def raising_propagator
          Class.new do
            include OpenFeature::SDK::TransactionContextPropagator

            def get_transaction_context = raise("propagator down")
          end.new
        end

        # Spec 1.4.11: the client reports failures through the details, never the log
        def expect_default(details, error_code, message = nil)
          expect(details.value).to be(false)
          expect(details.error_code).to eq(error_code)
          expect(details.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
          expect(details.error_message).to match(message) if message
          expect(logger).not_to have_received(:error)
        end

        before do
          OpenFeature::SDK.configuration.send(:reset)
          OpenFeature::SDK.configuration.logger = logger
        end

        after do
          OpenFeature::SDK.configuration.send(:reset)
          OpenFeature::SDK.configuration.logger = nil
        end

        specify "a propagator that does not implement get_transaction_context returns the default instead of raising" do
          OpenFeature::SDK.set_provider_and_wait(in_memory)
          OpenFeature::SDK.set_transaction_context_propagator(Class.new { include OpenFeature::SDK::TransactionContextPropagator }.new)

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false)

          expect_default(details, OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        end

        specify "a propagator that raises returns the default" do
          OpenFeature::SDK.set_provider_and_wait(in_memory)
          OpenFeature::SDK.set_transaction_context_propagator(raising_propagator)

          expect_default(OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false), OpenFeature::SDK::Provider::ErrorCode::GENERAL, /propagator down/)
        end

        specify "a Hash passed as evaluation context returns the default" do
          OpenFeature::SDK.set_provider_and_wait(in_memory)

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false, evaluation_context: {"targeting_key" => "user"})

          expect_default(details, OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        end

        specify "a provider that raises NotImplementedError returns the default" do
          OpenFeature::SDK.set_provider_and_wait(Class.new { def fetch_boolean_value(**) = raise(NotImplementedError, "no booleans") }.new)

          expect_default(OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false), OpenFeature::SDK::Provider::ErrorCode::GENERAL, /no booleans/)
        end

        specify "a provider that raises NotImplementedError still runs error hooks and gives finally hooks the default details" do
          seen = {}
          recorder = Class.new do
            include OpenFeature::SDK::Hooks::Hook

            define_method(:error) { |exception:, **| seen[:error] = exception.class }
            define_method(:finally) { |evaluation_details:, **| seen[:finally] = evaluation_details&.error_code }
          end.new
          OpenFeature::SDK.set_provider_and_wait(Class.new { def fetch_boolean_value(**) = raise(NotImplementedError, "no booleans") }.new)

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false, hooks: [recorder])

          expect_default(details, OpenFeature::SDK::Provider::ErrorCode::GENERAL, /no booleans/)
          expect(seen).to eq(error: NotImplementedError, finally: OpenFeature::SDK::Provider::ErrorCode::GENERAL)
        end

        specify "a provider whose hooks raise returns the default" do
          provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) { def hooks = raise("hooks down") }.new("flag" => true)
          OpenFeature::SDK.set_provider_and_wait(provider)

          expect_default(OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false), OpenFeature::SDK::Provider::ErrorCode::GENERAL, /hooks down/)
        end

        specify "a provider whose metadata raises returns the default" do
          provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
            attr_accessor :broken

            def metadata = broken ? raise("metadata down") : super
          end.new("flag" => true)
          OpenFeature::SDK.set_provider_and_wait(provider)
          provider.broken = true

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false, hooks: [hook])

          expect_default(details, OpenFeature::SDK::Provider::ErrorCode::GENERAL, /metadata down/)
        end

        specify "invalid hook hints return the default when hooks would receive them" do
          OpenFeature::SDK.set_provider_and_wait(in_memory)

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false, hooks: [hook], hook_hints: {"key" => Object.new})

          expect_default(details, OpenFeature::SDK::Provider::ErrorCode::GENERAL, /allowed/)
        end

        specify "invalid hook hints are ignored when no hooks are registered" do
          OpenFeature::SDK.set_provider_and_wait(in_memory)

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false, hook_hints: {"key" => Object.new})

          expect(details.value).to be(true)
          expect(details.error_code).to be_nil
        end

        specify "a provider error result returns the default and keeps the provider's error code" do
          resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(
            value: true, variant: "on", error_code: OpenFeature::SDK::Provider::ErrorCode::PARSE_ERROR, error_message: "bad json"
          )
          OpenFeature::SDK.set_provider_and_wait(resolving_provider(resolution))

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false)

          expect_default(details, OpenFeature::SDK::Provider::ErrorCode::PARSE_ERROR)
          expect(details.error_message).to eq("bad json")
          expect(details.variant).to be_nil
        end

        specify "a FLAG_NOT_FOUND result with a nil value keeps FLAG_NOT_FOUND through error hooks" do
          resolution = OpenFeature::SDK::Provider::ResolutionDetails.new(value: nil, error_code: OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
          OpenFeature::SDK.set_provider_and_wait(resolving_provider(resolution))
          hook_codes = []
          error_hook = Class.new do
            include OpenFeature::SDK::Hooks::Hook

            define_method(:error) { |exception:, **| hook_codes << exception.error_code }
          end.new

          details = OpenFeature::SDK.build_client.fetch_boolean_details(flag_key: "flag", default_value: false, hooks: [error_hook])

          expect_default(details, OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND)
          expect(hook_codes).to eq([OpenFeature::SDK::Provider::ErrorCode::FLAG_NOT_FOUND])
        end
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

    # Not a spec requirement since v0.9.0 (2.2.7 moved it to providers); evaluation_v2.feature still expects it.
    context "Short-circuit: provider not ready" do
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

    context "Short-circuit: provider fatal" do
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

  context "1.7 - Provider Lifecycle (shutdown)" do
    context "Requirement 1.7.6" do
      specify "shutdown must not emit PROVIDER_READY before transitioning to NOT_READY" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)

        states_observed = []
        handler = ->(event_details) { states_observed << :ready }

        OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, handler)

        # Clear any immediate handler invocation from registration
        states_observed.clear

        OpenFeature::SDK.shutdown

        expect(states_observed).not_to include(:ready)
      end
    end
  end

  context "1.1 - API Metadata" do
    context "Requirement 1.1.5" do
      specify "The API must provide a function for retrieving the metadata of the configured provider" do
        provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(provider)

        expect(OpenFeature::SDK).to respond_to(:provider_metadata)
        expect(OpenFeature::SDK.provider_metadata.name).to eq("In-memory Provider")
      end

      specify "provider_metadata accepts a domain parameter" do
        default_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        domain_provider = OpenFeature::SDK::Provider::NoOpProvider.new

        OpenFeature::SDK.set_provider_and_wait(default_provider)
        OpenFeature::SDK.set_provider_and_wait(domain_provider, domain: "my-domain")

        expect(OpenFeature::SDK.provider_metadata(domain: "my-domain").name).to eq("No-op Provider")
      end

      specify "provider_metadata falls back to default provider when domain has no binding" do
        default_provider = OpenFeature::SDK::Provider::InMemoryProvider.new
        OpenFeature::SDK.set_provider_and_wait(default_provider)

        expect(OpenFeature::SDK.provider_metadata(domain: "unknown").name).to eq("In-memory Provider")
      end

      specify "provider_metadata returns nil when no provider is configured" do
        OpenFeature::SDK.shutdown

        expect(OpenFeature::SDK.provider_metadata).to be_nil
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
