# frozen_string_literal: true

require "open_feature/sdk"

# Configure OpenFeature with the in-memory provider for demonstration
OpenFeature::SDK.configure do |config|
  config.set_provider(OpenFeature::SDK::Provider::InMemoryProvider.new(
    "v2_enabled" => true,
    "welcome_message" => "Hello, OpenFeature!",
    "item_limit" => 42,
    "theme" => {"color" => "blue", "mode" => "dark"}
  ))
end

# Create a client
client = OpenFeature::SDK.build_client

# Evaluate different flag types
puts client.fetch_boolean_value(flag_key: "v2_enabled", default_value: false)
puts client.fetch_string_value(flag_key: "welcome_message", default_value: "default")
puts client.fetch_number_value(flag_key: "item_limit", default_value: 10)
puts client.fetch_object_value(flag_key: "theme", default_value: {})
