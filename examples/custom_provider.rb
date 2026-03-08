# frozen_string_literal: true

require "open_feature/sdk"

# A minimal custom provider demonstrating the duck type interface.
# Any object implementing the fetch_*_value methods works as a provider.
class MyProvider
  def metadata
    OpenFeature::SDK::Provider::ProviderMetadata.new(name: "my-provider")
  end

  def init(evaluation_context = nil)
    # Perform setup (connect to flag service, load config, etc.)
  end

  def shutdown
    # Clean up resources
  end

  def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
    OpenFeature::SDK::Provider::ResolutionDetails.new(
      value: true,
      reason: "STATIC",
      variant: "on"
    )
  end

  # The remaining methods return the default value for brevity.
  # A real provider would look up each flag_key in its flag management system.
  def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
    OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
  end

  def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
    OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
  end

  def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
    OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
  end

  def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
    OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
  end

  def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
    OpenFeature::SDK::Provider::ResolutionDetails.new(value: default_value)
  end
end

OpenFeature::SDK.configure do |config|
  config.set_provider(MyProvider.new)
end

client = OpenFeature::SDK.build_client
puts client.fetch_boolean_value(flag_key: "any_flag", default_value: false)
