# frozen_string_literal: true

RSpec.describe OpenFeature::SDK do
  it "has a version number" do
    expect(OpenFeature::SDK::VERSION).not_to be_nil
  end

  it "can be configured" do
    expect(OpenFeature::SDK).to respond_to(:configure)

    OpenFeature::SDK.configure do |config|
      # don't test here, rely on OpenFeature::SDK::API instead
    end
  end
end
