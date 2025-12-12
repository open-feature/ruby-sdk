<!-- markdownlint-disable MD033 -->
<!-- x-hide-in-docs-start -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/white/openfeature-horizontal-white.svg" />
    <img align="center" alt="OpenFeature Logo" src="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/black/openfeature-horizontal-black.svg" />
  </picture>
</p>

<h2 align="center">OpenFeature Ruby SDK</h2>

<!-- x-hide-in-docs-end -->
<!-- The 'github-badges' class is used in the docs -->
<p align="center" class="github-badges">
  <a href="https://github.com/open-feature/spec/releases/tag/v0.8.0">
    <img alt="Specification" src="https://img.shields.io/static/v1?label=specification&message=v0.8.0&color=yellow&style=for-the-badge" />
  </a>
  <!-- x-release-please-start-version -->

  <a href="https://github.com/open-feature/ruby-sdk/releases/tag/v0.4.1">
    <img alt="Release" src="https://img.shields.io/static/v1?label=release&message=v0.4.1&color=blue&style=for-the-badge" />
  </a>

  <!-- x-release-please-end -->
  <br/>
  <a href="https://bestpractices.coreinfrastructure.org/projects/9337">
    <img alt="CII Best Practices" src="https://bestpractices.coreinfrastructure.org/projects/9337/badge" />
  </a>
</p>
<!-- x-hide-in-docs-start -->

[OpenFeature](https://openfeature.dev) is an open specification that provides a vendor-agnostic, community-driven API for feature flagging that works with your favorite feature flag management tool or in-house solution.

<!-- x-hide-in-docs-end -->
## 🚀 Quick start

### Requirements

| Supported Ruby Version | OS                    |
| ------------ | --------------------- |
| Ruby 3.1.4   | Windows, MacOS, Linux |
| Ruby 3.2.3   | Windows, MacOS, Linux |
| Ruby 3.3.0   | Windows, MacOS, Linux |

### Install

Install the gem and add to the application's Gemfile by executing:

```sh
bundle add openfeature-sdk
```

If bundler is not being used to manage dependencies, install the gem by executing:

```sh
gem install openfeature-sdk
```

### Usage

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
end

# Create a client
client = OpenFeature::SDK.build_client

# fetching boolean value feature flag
bool_value = client.fetch_boolean_value(flag_key: 'boolean_flag', default_value: false)

# a details method is also available for more information about the flag evaluation
# see `ResolutionDetails` for more info
bool_details = client.fetch_boolean_details(flag_key: 'boolean_flag', default_value: false)

# fetching string value feature flag
string_value = client.fetch_string_value(flag_key: 'string_flag', default_value: 'default')

# fetching number value feature flag
float_value = client.fetch_number_value(flag_key: 'number_value', default_value: 1.0)
integer_value = client.fetch_number_value(flag_key: 'number_value', default_value: 1)

# get an object value
object = client.fetch_object_value(flag_key: 'object_value', default_value: { name: 'object'})
```

## 🌟 Features

| Status | Features                                                            | Description                                                                                                                                                  |
| ------ | --------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ✅      | [Providers](#providers)                                             | Integrate with a commercial, open source, or in-house feature management tool.                                                                               |
| ✅      | [Targeting](#targeting)                                             | Contextually-aware flag evaluation using [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context).                           |
| ⚠️      | [Hooks](#hooks)                                                     | Add functionality to various stages of the flag evaluation life-cycle.                                                                                       |
| ❌      | [Logging](#logging)                                                 | Integrate with popular logging packages.                                                                                                                     |
| ✅      | [Domains](#domains)                                                 | Logically bind clients with providers.                                                                                                                       |
| ✅      | [Eventing](#eventing)                                               | React to state changes in the provider or flag management system.                                                                                            |
| ⚠️      | [Shutdown](#shutdown)                                               | Gracefully clean up a provider during application shutdown.                                                                                                  |
| ❌      | [Transaction Context Propagation](#transaction-context-propagation) | Set a specific [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context) for a transaction (e.g. an HTTP request or a thread) |
| ⚠️      | [Extending](#extending)                                             | Extend OpenFeature with custom providers and hooks.                                                                                                          |

<sub>Implemented: ✅ | In-progress: ⚠️ | Not implemented yet: ❌</sub>

### Providers

[Providers](https://openfeature.dev/docs/reference/concepts/provider) are an abstraction between a flag management system and the OpenFeature SDK.
Look [here](https://openfeature.dev/ecosystem?instant_search%5BrefinementList%5D%5Btype%5D%5B0%5D=Provider&instant_search%5BrefinementList%5D%5Btechnology%5D%5B0%5D=Ruby) for a complete list of available providers.
If the provider you're looking for hasn't been created yet, see the [develop a provider](#develop-a-provider) section to learn how to build it yourself.

Once you've added a provider as a dependency, it can be registered with OpenFeature like this:

```ruby
OpenFeature::SDK.configure do |config|
  # your provider of choice, which will be used as the default provider
  config.set_provider(OpenFeature::SDK::Provider::InMemoryProvider.new(
    {
      "v2_enabled" => true,
    }
  ))
end
```

#### Blocking Provider Registration

If you need to ensure that a provider is fully initialized before continuing, you can use `set_provider_and_wait`:

```ruby
# Using the SDK directly
begin
  OpenFeature::SDK.set_provider_and_wait(my_provider)
  puts "Provider is ready!"
rescue OpenFeature::SDK::ProviderInitializationError => e
  puts "Provider failed to initialize: #{e.message}"
  puts "Error code: #{e.error_code}"
  # Note: original_error is only present for timeout errors, nil for provider event errors
  puts "Original error: #{e.original_error}" if e.original_error
end

# With custom timeout (default is 30 seconds)
OpenFeature::SDK.set_provider_and_wait(my_provider, timeout: 60)

# Domain-specific provider
OpenFeature::SDK.set_provider_and_wait(my_provider, domain: "feature-flags")

# Via configuration block
OpenFeature::SDK.configure do |config|
  begin
    config.set_provider_and_wait(my_provider)
  rescue OpenFeature::SDK::ProviderInitializationError => e
    # Handle initialization failure
  end
end
```

The `set_provider_and_wait` method:
- Waits for the provider's `init` method to complete successfully
- Raises `ProviderInitializationError` with `PROVIDER_FATAL` error code if initialization fails or times out
- Provides access to the provider instance and error code for debugging
- The `original_error` field only contains the underlying exception for timeout errors; it is `nil` for errors that occur through the provider event system
- Uses the same thread-safe provider switching as `set_provider`

In some situations, it may be beneficial to register multiple providers in the same application.
This is possible using [domains](#domains), which is covered in more detail below.

### Targeting

Sometimes, the value of a flag must consider some dynamic criteria about the application or user, such as the user's location, IP, email address, or the server's location.
In OpenFeature, we refer to this as [targeting](https://openfeature.dev/specification/glossary#targeting).
If the flag management system you're using supports targeting, you can provide the input data using the [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context).

```ruby
OpenFeature::SDK.configure do |config|
  # you can set a global evaluation context here
  config.evaluation_context = OpenFeature::SDK::EvaluationContext.new("host" => "myhost.com")
end

# Evaluation context can be set on a client as well
client_with_context = OpenFeature::SDK.build_client(
  evaluation_context: OpenFeature::SDK::EvaluationContext.new("controller_name" => "admin")
)

# Invocation evaluation context can also be passed in during flag evaluation.
# During flag evaluation, invocation context takes precedence over client context
# which takes precedence over API (aka global) context.
bool_value = client.fetch_boolean_value(
  flag_key: 'boolean_flag',
  default_value: false,
  evaluation_context: OpenFeature::SDK::EvaluationContext.new("is_friday" => true)
)
```

### Hooks

Coming Soon! [Issue available](https://github.com/open-feature/ruby-sdk/issues/52) to be worked on.

<!-- [Hooks](https://openfeature.dev/docs/reference/concepts/hooks) allow for custom logic to be added at well-defined points of the flag evaluation life-cycle.
Look [here](https://openfeature.dev/ecosystem/?instant_search%5BrefinementList%5D%5Btype%5D%5B0%5D=Hook&instant_search%5BrefinementList%5D%5Btechnology%5D%5B0%5D=Ruby) for a complete list of available hooks.
If the hook you're looking for hasn't been created yet, see the [develop a hook](#develop-a-hook) section to learn how to build it yourself.

Once you've added a hook as a dependency, it can be registered at the global, client, or flag invocation level. -->

<!-- TODO: code example of setting hooks at all levels -->

### Logging

Coming Soon! [Issue available](https://github.com/open-feature/ruby-sdk/issues/148) to work on.

<!-- TODO: talk about logging config and include a code example -->

### Domains

Clients can be assigned to a domain. A domain is a logical identifier which can be used to associate clients with a particular provider.
If a domain has no associated provider, the default provider is used.

```ruby
OpenFeature::SDK.configure do |config|
  config.set_provider(OpenFeature::SDK::Provider::NoOpProvider.new, domain: "legacy_flags")
end

# Create a client for a different domain, this will use the provider assigned to that domain
legacy_flag_client = OpenFeature::SDK.build_client(domain: "legacy_flags")
```

### Eventing

Events allow you to react to state changes in the provider or underlying flag management system, such as flag definition changes, provider readiness, or error conditions.
Initialization events (`PROVIDER_READY` on success, `PROVIDER_ERROR` on failure) are dispatched for every provider.
Some providers support additional events, such as `PROVIDER_CONFIGURATION_CHANGED`.

Please refer to the documentation of the provider you're using to see what events are supported.

```ruby
# Register event handlers at the API (global) level
ready_handler = ->(event_details) do
  puts "Provider #{event_details[:provider].metadata.name} is ready!"
end

OpenFeature::SDK.add_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ready_handler)

# Providers can emit events using the EventHandler mixin
class MyEventAwareProvider
  include OpenFeature::SDK::Provider::EventHandler

  def init(evaluation_context)
    # During initialization, emit PROVIDER_READY when ready
    emit_event(OpenFeature::SDK::ProviderEvent::PROVIDER_READY)
  end
end

# Remove specific handlers when no longer needed
OpenFeature::SDK.remove_handler(OpenFeature::SDK::ProviderEvent::PROVIDER_READY, ready_handler)
```

### Shutdown

Coming Soon! [Issue available](https://github.com/open-feature/ruby-sdk/issues/149) to be worked on.

<!-- TODO The OpenFeature API provides a close function to perform a cleanup of all registered providers.
This should only be called when your application is in the process of shutting down.

```ruby
class MyProvider
  def shutdown
    # Perform any shutdown/reclamation steps with flag management system here
    # Return value is ignored
  end
end
``` -->

### Transaction Context Propagation

Coming Soon! [Issue available](https://github.com/open-feature/ruby-sdk/issues/150) to be worked on.

<!-- Transaction context is a container for transaction-specific evaluation context (e.g. user id, user agent, IP).
Transaction context can be set where specific data is available (e.g. an auth service or request handler) and by using the transaction context propagator it will automatically be applied to all flag evaluations within a transaction (e.g. a request or thread). -->

<!-- TODO: code example for global shutdown -->

## Extending

### Develop a provider

To develop a provider, you need to create a new project and include the OpenFeature SDK as a dependency.
This can be a new repository or included in [the existing contrib repository](https://github.com/open-feature/ruby-sdk-contrib) available under the OpenFeature organization.
You’ll then need to write the provider by implementing the `Provider` duck.

```ruby
class MyProvider
  def init
    # Perform any initialization steps with flag management system here
    # Return value is ignored
    # **Note** The OpenFeature spec defines a lifecycle method called `initialize` to be called when a new provider is set.
    # To avoid conflicting with the Ruby `initialize` method, this method should be named `init` when creating a provider.
  end

  def shutdown
    # Perform any shutdown/reclamation steps with flag management system here
    # Return value is ignored
  end

  def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
    # Retrieve a boolean value from provider source
  end

  def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
    # Retrieve a string value from provider source
  end

  def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
    # Retrieve a numeric value from provider source
  end

  def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
    # Retrieve a integer value from provider source
  end

  def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
    # Retrieve a float value from provider source
  end

  def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
    # Retrieve a hash value from provider source
  end
end
```

> Built a new provider? [Let us know](https://github.com/open-feature/openfeature.dev/issues/new?assignees=&labels=provider&projects=&template=document-provider.yaml&title=%5BProvider%5D%3A+) so we can add it to the docs!

### Develop a hook

Coming Soon! [Issue available](https://github.com/open-feature/ruby-sdk/issues/52) to be worked on.

<!-- To develop a hook, you need to create a new project and include the OpenFeature SDK as a dependency.
This can be a new repository or included in [the existing contrib repository](https://github.com/open-feature/ruby-sdk-contrib) available under the OpenFeature organization.
Implement your own hook by conforming to the `Hook interface`.
To satisfy the interface, all methods (`Before`/`After`/`Finally`/`Error`) need to be defined.
To avoid defining empty functions, make use of the `UnimplementedHook` struct (which already implements all the empty functions). -->

<!-- TODO: code example of hook implementation -->

<!-- > Built a new hook? [Let us know](https://github.com/open-feature/openfeature.dev/issues/new?assignees=&labels=hook&projects=&template=document-hook.yaml&title=%5BHook%5D%3A+) so we can add it to the docs! -->

<!-- x-hide-in-docs-start -->
## ⭐️ Support the project

- Give this repo a ⭐️!
- Follow us on social media:
  - Twitter: [@openfeature](https://twitter.com/openfeature)
  - LinkedIn: [OpenFeature](https://www.linkedin.com/company/openfeature/)
- Join us on [Slack](https://cloud-native.slack.com/archives/C0344AANLA1)
- For more, check out our [community page](https://openfeature.dev/community/)

## 🤝 Contributing

Interested in contributing? Great, we'd love your help! To get started, take a look at the [CONTRIBUTING](CONTRIBUTING.md) guide.

### Thanks to everyone who has already contributed

<a href="https://github.com/open-feature/ruby-sdk/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=open-feature/ruby-sdk" alt="Pictures of the folks who have contributed to the project" />
</a>


Made with [contrib.rocks](https://contrib.rocks).
<!-- x-hide-in-docs-end -->
