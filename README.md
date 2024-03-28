# OpenFeature SDK for Ruby

[![a](https://img.shields.io/badge/slack-%40cncf%2Fopenfeature-brightgreen?style=flat&logo=slack)](https://cloud-native.slack.com/archives/C0344AANLA1)
[![v0.5.1](https://img.shields.io/static/v1?label=Specification&message=v0.5.1&color=yellow)](https://github.com/open-feature/spec/tree/v0.5.1)
![Ruby](https://img.shields.io/badge/ruby-%23CC342D.svg?style=for-the-badge&logo=ruby&logoColor=white)
![Build](https://github.com/open-feature/openfeature-ruby/actions/workflows/main.yml/badge.svg?branch=main)
![Gem version](https://img.shields.io/gem/v/openfeature-sdk)

This is the Ruby implementation of [OpenFeature](https://openfeature.dev), a vendor-agnostic abstraction library for evaluating feature flags.

We support multiple data types for flags (numbers, strings, booleans, objects) as well as hooks, which can alter the lifecycle of a flag evaluation.

## Support Matrix

| Ruby Version | OS                    |
| ------------ | --------------------- |
| Ruby 3.1.4   | Windows, MacOS, Linux |
| Ruby 3.2.3   | Windows, MacOS, Linux |
| Ruby 3.3.0   | Windows, MacOS, Linux |

## Installation

Install the gem and add to the application's Gemfile by executing:

```sh
bundle add openfeature-sdk
```

If bundler is not being used to manage dependencies, install the gem by executing:

```sh
gem install openfeature-sdk
```

## Usage

```ruby
require 'open_feature/sdk'
require 'json' # For JSON.dump

# API Initialization and configuration

OpenFeature::SDK.configure do |config|
  # your provider of choice, which will be used as the default provider
  config.set_provider(OpenFeature::SDK::Provider::InMemoryProvider.new(
    {
      "flag1" => true,
      "flag2" => 1
    }
  ))
  # alternatively, you can bind multiple providers to different domains
  config.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new, domain: "legacy_flags")
end

# Create a client
client = OpenFeature::SDK.build_client
# Create a client for a different domain, this will use the provider assigned to that domain
legacy_flag_client = OpenFeature::SDK.build_client(domain: "legacy_flags")

# fetching boolean value feature flag
bool_value = client.fetch_boolean_value(flag_key: 'boolean_flag', default_value: false)

# fetching string value feature flag
string_value = client.fetch_string_value(flag_key: 'string_flag', default_value: false)

# fetching number value feature flag
float_value = client.fetch_number_value(flag_key: 'number_value', default_value: 1.0)
integer_value = client.fetch_number_value(flag_key: 'number_value', default_value: 1)

# get an object value
object = client.fetch_object_value(flag_key: 'object_value', default_value: JSON.dump({ name: 'object'}))
```

For complete documentation, visit: https://openfeature.dev/docs/category/concepts

### Providers

Providers are the abstraction layer between OpenFeature and different flag management systems.

The `NoOpProvider` is an example of a minimalist provider. The `InMemoryProvider` is a provider that can be initialized with flags and used to store flags in process. For complete documentation on the Provider interface, visit: https://openfeature.dev/specification/sections/providers.

In addition to the `fetch_*` methods, providers can optionally implement lifecycle methods that are invoked when the underlying provider is switched out. For example:

```ruby
class MyProvider
  def init
    # Perform any initialization steps with flag management system here
    # Return value is ignored
  end

  def shutdown
    # Perform any shutdown/reclamation steps with flag management system here
    # Return value is ignored
  end
end
```

**Note** The OpenFeature spec defines a lifecycle method called `initialize` to be called when a new provider is set. To avoid conflicting with the Ruby `initialize` method, this method should be named `init` when creating a provider.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to the OpenFeature project.

Our community meetings are held regularly and open to everyone. Check the [OpenFeature community calendar](https://calendar.google.com/calendar/u/0?cid=MHVhN2kxaGl2NWRoMThiMjd0b2FoNjM2NDRAZ3JvdXAuY2FsZW5kYXIuZ29vZ2xlLmNvbQ) for specific dates and for the Zoom meeting links.

## License

[Apache License 2.0](LICENSE)
