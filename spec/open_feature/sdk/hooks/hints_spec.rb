# frozen_string_literal: true

require "spec_helper"

require "open_feature/sdk/hooks/hints"

RSpec.describe OpenFeature::SDK::Hooks::Hints do
  let(:hint_hash) { {key: [], nested: {key: []}} }
  subject(:hints) { described_class.new(hint_hash) }
  context "Immutability" do
    it "is frozen" do
      expect(hints).to be_frozen
    end

    it "does not allow addition of new keys" do
      expect { hints[:new_key] = "new_value" }.to raise_error(FrozenError)
    end

    it "does allow modification of existing values" do
      expect(hints[:key]).to_not be_frozen
      expect { hints[:key] << "abc" }.to_not raise_error
    end

    it "does not allow deletion of keys" do
      expect { hints.delete(:key) }.to raise_error(FrozenError)
    end

    it "allows reading of keys" do
      expect(hints[:key]).to eq([])
    end

    it "only allows string keys" do
      expect { described_class.new(1 => []) }.to raise_error(ArgumentError) do |e|
        expect(e.message).to include("Only String or Symbol are allowed as keys")
      end
    end

    it "only allows values of certain types" do
      expect { described_class.new(key: Object.new) }.to raise_error(ArgumentError) do |e|
        expect(e.message).to include("Only String, Symbol, Numeric, TrueClass, FalseClass, Time, Hash, Array are allowed as values")
      end
    end

    it "does not freeze the original hash" do
      expect(hint_hash).not_to be_frozen
    end
  end
end
