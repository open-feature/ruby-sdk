# frozen_string_literal: true

require "sinatra"
require "cowsay"
require "openfeature/sdk"

OpenFeature::SDK.configure do |config|
  config.provider = OpenFeature::SDK::Provider::NoOpProvider.new
end
feature_flags = OpenFeature::SDK.build_client(name: "my-app")

get "/" do
  if feature_flags.fetch_boolean_value(flag_key: "with-cows", default_value: false)
    "<pre>#{Cowsay.say "Hello, world!", "cow"}</pre>"
  else
    "<p>Hello, world!</p>"
  end
end
