# frozen_string_literal: true

require "spec_helper"
require "open_feature/sdk/isolated"

RSpec.describe "Isolated API instances" do
  let(:global) { OpenFeature::SDK::API.instance }
  let(:isolated) { OpenFeature::SDK::Isolated.create_api }

  def in_memory(flags)
    OpenFeature::SDK::Provider::InMemoryProvider.new(flags)
  end

  def targeting_key_flag
    {"who" => ->(context) { context&.targeting_key.to_s }}
  end

  def context(targeting_key)
    OpenFeature::SDK::EvaluationContext.new(targeting_key:)
  end

  def run_ruby(code)
    IO.popen([RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", code], err: [:child, :out], &:read)
  end

  before { global.configuration.send(:reset) }

  after do
    isolated.shutdown
    global.shutdown
  end

  context "Requirement 1.8.1" do
    specify "create_api returns a new API independent of the global one" do
      other = OpenFeature::SDK::Isolated.create_api

      expect(isolated).to be_a(OpenFeature::SDK::API)
      expect([isolated, other, global].uniq(&:object_id).size).to eq(3)
      expect([isolated, other, global].map(&:configuration).uniq(&:object_id).size).to eq(3)
    ensure
      other&.shutdown
    end
  end

  context "Requirement 1.8.2" do
    specify "an isolated API's client uses that API's provider, hooks and context" do
      calls = []
      global.set_provider_and_wait(in_memory({"flag" => false}.merge(targeting_key_flag)))
      isolated.set_provider_and_wait(in_memory({"flag" => true}.merge(targeting_key_flag)))
      isolated.add_hooks(recording_hook("isolated", calls))
      global.configure { |config| config.evaluation_context = context("global") }
      isolated.configure { |config| config.evaluation_context = context("isolated") }
      global_client = global.build_client
      isolated_client = isolated.build_client

      expect(global_client.fetch_boolean_value(flag_key: "flag", default_value: true)).to be(false)
      expect(global_client.fetch_string_value(flag_key: "who", default_value: "")).to eq("global")
      expect(calls).to be_empty

      expect(isolated_client.fetch_boolean_value(flag_key: "flag", default_value: false)).to be(true)
      expect(isolated_client.fetch_string_value(flag_key: "who", default_value: "")).to eq("isolated")
      expect(calls).to include("isolated:before")
    end

    specify "shutdown on an isolated API doesn't affect the global API" do
      global.set_provider_and_wait(in_memory({"flag" => true}))
      isolated.set_provider_and_wait(in_memory({"flag" => true}))
      hook = recording_hook("global", [])
      global.add_hooks(hook)
      global.configure { |config| config.evaluation_context = context("global") }

      isolated.shutdown

      expect(isolated.build_client.fetch_boolean_value(flag_key: "flag", default_value: false)).to be(false)
      expect(global.build_client.fetch_boolean_value(flag_key: "flag", default_value: false)).to be(true)
      expect(global.hooks).to eq([hook])
      expect(global.evaluation_context.targeting_key).to eq("global")
    end

    specify "shutdown on the global API doesn't affect an isolated API" do
      global.set_provider_and_wait(in_memory({"flag" => true}))
      isolated.set_provider_and_wait(in_memory({"flag" => true}))
      hook = recording_hook("isolated", [])
      isolated.add_hooks(hook)
      isolated.configure { |config| config.evaluation_context = context("isolated") }

      global.shutdown

      expect(global.build_client.fetch_boolean_value(flag_key: "flag", default_value: false)).to be(false)
      expect(isolated.build_client.fetch_boolean_value(flag_key: "flag", default_value: false)).to be(true)
      expect(isolated.hooks).to eq([hook])
      expect(isolated.evaluation_context.targeting_key).to eq("isolated")
    end

    specify "an isolated API's provider events reach only its own handlers" do
      calls = []
      {global: global, isolated: isolated}.each do |name, api|
        client = api.build_client
        [OpenFeature::SDK::ProviderEvent::PROVIDER_READY, OpenFeature::SDK::ProviderEvent::PROVIDER_STALE].each do |event|
          api.add_handler(event, ->(_) { calls << [name, :api, event] })
          client.add_handler(event, ->(_) { calls << [name, :client, event] })
        end
      end
      provider = in_memory({"flag" => true})

      isolated.set_provider_and_wait(provider)
      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(calls).to contain_exactly(
        [:isolated, :api, OpenFeature::SDK::ProviderEvent::PROVIDER_READY],
        [:isolated, :client, OpenFeature::SDK::ProviderEvent::PROVIDER_READY],
        [:isolated, :api, OpenFeature::SDK::ProviderEvent::PROVIDER_STALE],
        [:isolated, :client, OpenFeature::SDK::ProviderEvent::PROVIDER_STALE]
      )
    end

    specify "two APIs with thread-local propagators keep separate transaction contexts" do
      global.set_provider_and_wait(in_memory(targeting_key_flag))
      isolated.set_provider_and_wait(in_memory(targeting_key_flag))
      [global, isolated].each { |api| api.set_transaction_context_propagator(OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new) }

      global.set_transaction_context(context("global"))
      isolated.set_transaction_context(context("isolated"))

      expect(global.build_client.fetch_string_value(flag_key: "who", default_value: "")).to eq("global")
      expect(isolated.build_client.fetch_string_value(flag_key: "who", default_value: "")).to eq("isolated")
    end
  end

  context "Requirement 1.8.3" do
    specify "the factory isn't loaded by open_feature/sdk" do
      output = run_ruby('require "open_feature/sdk"; p defined?(OpenFeature::SDK::Isolated); require "open_feature/sdk/isolated"; p defined?(OpenFeature::SDK::Isolated)')

      expect(output.lines.map(&:chomp)).to eq(["nil", '"constant"'])
    end

    specify "requiring open_feature/sdk/isolated alone is enough to use it" do
      output = run_ruby(<<~RUBY)
        require "open_feature/sdk/isolated"
        api = OpenFeature::SDK::Isolated.create_api
        api.set_provider_and_wait(OpenFeature::SDK::Provider::InMemoryProvider.new("flag" => true))
        p api.build_client.fetch_boolean_value(flag_key: "flag", default_value: false)
      RUBY

      expect(output.chomp).to eq("true")
    end
  end

  context "Requirement 1.8.4" do
    specify "a provider with its own @configuration can include EventEmitter" do
      provider = Class.new(OpenFeature::SDK::Provider::InMemoryProvider) do
        attr_reader :configuration

        def initialize
          super
          @configuration = {sdk_key: "abc"}
        end
      end.new
      received = []
      OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE, ->(_details) { received << :stale })

      OpenFeature::SDK.set_provider_and_wait(provider)
      provider.emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_STALE)

      expect(received).to eq([:stale])
      expect(provider.configuration).to eq(sdk_key: "abc")
    end

    specify "a provider registered with one API can't be registered with another until the first shuts down" do
      provider = in_memory({"flag" => true})
      global.set_provider_and_wait(provider)

      expect { isolated.set_provider(provider) }.to raise_error(ArgumentError, /another OpenFeature API instance/)
      expect(isolated.provider).to be_nil

      global.shutdown
      isolated.set_provider_and_wait(provider)

      expect(isolated.build_client.fetch_boolean_value(flag_key: "flag", default_value: false)).to be(true)
    end

    specify "a provider replaced on one API can be registered with another" do
      provider = in_memory({"flag" => true})
      isolated.set_provider_and_wait(provider)
      isolated.set_provider_and_wait(in_memory({}))

      global.set_provider_and_wait(provider)

      expect(global.build_client.fetch_boolean_value(flag_key: "flag", default_value: false)).to be(true)
    end
  end
end
