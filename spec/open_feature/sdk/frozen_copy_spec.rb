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

  it "freezes a copy of a Time, since localtime and utc change the receiver" do
    time = Time.now
    copy = described_class.of(time)

    expect(copy).to be_frozen
    expect(time).not_to be_frozen
  end
end
