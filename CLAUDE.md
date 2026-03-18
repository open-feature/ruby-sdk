# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the official OpenFeature SDK for Ruby — an implementation of the [OpenFeature specification](https://openfeature.dev) providing a vendor-agnostic API for feature flag evaluation. Published as the `openfeature-sdk` gem. Requires Ruby >= 3.1.

## Commands

- **Install dependencies:** `bundle install`
- **Run all tests:** `bundle exec rspec`
- **Run a single test file:** `bundle exec rspec spec/open_feature/sdk/client_spec.rb`
- **Run a specific test by line:** `bundle exec rspec spec/open_feature/sdk/client_spec.rb:43`
- **Lint:** `bundle exec standardrb`
- **Lint with autofix:** `bundle exec standardrb --fix`
- **Type check:** `bundle exec steep check`
- **Default rake (tests + lint):** `bundle exec rake`

Note: Linting uses [Standard Ruby](https://github.com/standardrb/standard) (configured via the `standard` gem), which enforces double-quoted strings and its own opinionated style. There is no `.rubocop.yml` — Standard manages RuboCop configuration internally. Do not use `bundle exec rubocop` directly as a stale RuboCop server may apply different rules; always use `bundle exec standardrb`.

## Architecture

### Entry point and API singleton

`OpenFeature::SDK` (in `lib/open_feature/sdk.rb`) delegates all method calls to `API.instance` via `method_missing`. `API` is a Singleton that holds a `Configuration` object and builds `Client` instances.

### Provider duck type

Providers are not subclasses — they follow a duck type interface. Any object implementing `fetch_boolean_value`, `fetch_string_value`, `fetch_number_value`, `fetch_integer_value`, `fetch_float_value`, and `fetch_object_value` (all accepting `flag_key:`, `default_value:`, `evaluation_context:`) works as a provider. Each method must return a `ResolutionDetails` struct. Two built-in providers exist: `NoOpProvider` (default) and `InMemoryProvider` (for testing). Providers may optionally implement `init(evaluation_context)`, `shutdown`, and `metadata`.

### Client dynamic method generation

`Client` uses `class_eval` to metaprogram `fetch_<type>_value` and `fetch_<type>_details` methods from `RESULT_TYPE` and `SUFFIXES` arrays. This generates 12 public methods (6 types × 2 suffixes).

### Evaluation context merging

`EvaluationContextBuilder` merges three layers of context with this precedence: invocation > client > API (global). Context is a hash-like object with a special `targeting_key` field.

### Provider eventing

`Configuration` manages provider lifecycle events (READY, ERROR, STALE, CONFIGURATION_CHANGED). Providers can emit spontaneous events by including `Provider::EventEmitter`. Event handlers can be registered at API level (global) or client level (domain-scoped). `ProviderStateRegistry` tracks provider states; `EventDispatcher` manages handler registration and invocation.

### Domain-based provider binding

Providers can be registered for specific domains. `Configuration#provider(domain:)` resolves domain-specific providers, falling back to the default (nil-domain) provider. Clients are built with an optional `domain:` that binds them to a specific provider.

## Conventions

- All `.rb` files must have `# frozen_string_literal: true` as the first line.
- Tests live under `spec/` and mirror the `lib/` structure. `spec/specification/` contains tests mapped to OpenFeature spec requirements.
- RBS type signatures live under `sig/` and mirror the `lib/` structure. When changing any file under `lib/`, always update the corresponding `.rbs` file under `sig/` to reflect the new or modified method signatures, constants, or class structure. Run `bundle exec steep check` to verify type correctness after changes.
- Always sign git commits using the `-S` flag.
- Always include DCO sign-off in commits using the `-s` flag (i.e., `git commit -s -S`). This adds a `Signed-off-by` trailer required by the project's CI.
