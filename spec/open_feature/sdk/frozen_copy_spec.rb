# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenFeature::SDK::FrozenCopy do
  it "returns a deep-frozen copy without freezing the original" do
    source = {"list" => [+"a"]}
    copy = described_class.of(source)

    expect(copy["list"].first).to be_frozen
    expect(source["list"]).not_to be_frozen
  end

  it "copies what it can, item by item, when something inside can't be copied" do
    queue = Thread::Queue.new
    source = {"list" => [+"a"], "queue" => queue, "lookup" => Hash.new { |hash, key| hash[key] = key }}
    copy = described_class.of(source)

    expect(copy).to be_frozen
    expect(copy["list"]).to be_frozen
    expect(copy["list"].first).to be_frozen
    expect(copy["lookup"]).to be_frozen
    expect(copy["queue"]).to equal(queue)
    expect(source["list"]).not_to be_frozen
  end

  it "copies a cycle as a cycle of copies" do
    source = [Thread::Queue.new]
    source << source
    copy = described_class.of(source)

    expect(copy).to be_frozen
    expect(copy[1]).to equal(copy)
  end

  it "copies a structure shared in two places once, without handing back the original" do
    inner = [Thread::Queue.new, +"s"]
    copy = described_class.of({"a" => inner, "b" => inner})

    expect(copy["b"]).not_to equal(inner)
    expect(copy["b"]).to equal(copy["a"])
    expect(copy["b"]).to be_frozen
  end

  it "passes objects that aren't spec value types through untouched" do
    user = Struct.new(:name).new(+"Ada")
    copy = described_class.of({"user" => user})

    expect(copy["user"]).to equal(user)
    expect(user).not_to be_frozen
  end

  it "gives a Time its own copy, left unfrozen so utc and localtime still work without touching the original" do
    time = Time.new(2026, 1, 1, 12, 0, 0, "+05:00")
    copy = described_class.of(time)
    copy.utc

    expect(copy).not_to equal(time)
    expect(time.utc_offset).to eq(5 * 3600)
  end

  it "drops a Hash's default proc, which a frozen copy couldn't run" do
    copy = described_class.of(Hash.new { |hash, key| hash[key] = [] }.merge("a" => 1))

    expect(copy["missing"]).to be_nil
    expect(copy["a"]).to eq(1)
  end

  it "copies a Hash's default value too" do
    regions = [+"us"]
    copy = described_class.of(Hash.new(regions))

    expect { copy["missing"] << "eu" }.to raise_error(FrozenError)
    expect(regions).to eq(["us"])
  end

  it "works on a Ruby without Ractor" do
    hide_const("Ractor")
    source = {"list" => [+"a"]}

    expect(described_class.of(source)["list"].first).to be_frozen
    expect(source["list"]).not_to be_frozen
  end
end
