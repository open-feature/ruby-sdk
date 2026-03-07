# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::ThreadLocalTransactionContextPropagator do
  subject(:propagator) { described_class.new }

  after do
    Thread.current[described_class::THREAD_KEY] = nil
  end

  describe "#set_transaction_context / #get_transaction_context" do
    it "round-trips an evaluation context" do
      context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-123")
      propagator.set_transaction_context(context)

      expect(propagator.get_transaction_context).to eq(context)
    end

    it "returns nil when no context has been set" do
      expect(propagator.get_transaction_context).to be_nil
    end

    it "isolates context between threads" do
      context = OpenFeature::SDK::EvaluationContext.new(targeting_key: "main-thread")
      propagator.set_transaction_context(context)

      other_thread_context = nil
      Thread.new { other_thread_context = propagator.get_transaction_context }.join

      expect(other_thread_context).to be_nil
      expect(propagator.get_transaction_context).to eq(context)
    end
  end
end

RSpec.describe OpenFeature::SDK::TransactionContextPropagator do
  describe "interface contract" do
    let(:klass) do
      Class.new do
        include OpenFeature::SDK::TransactionContextPropagator
      end
    end

    it "raises NotImplementedError for #set_transaction_context" do
      expect { klass.new.set_transaction_context(nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #get_transaction_context" do
      expect { klass.new.get_transaction_context }.to raise_error(NotImplementedError)
    end
  end
end
