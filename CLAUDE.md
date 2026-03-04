# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenFeature Ruby SDK — implements the [OpenFeature specification](https://openfeature.dev) (v0.8.0) for vendor-agnostic feature flag management. Published as the `openfeature-sdk` gem. Pure Ruby, no runtime dependencies. Requires Ruby >= 3.1.

## Commands

```bash
# Install dependencies
bundle install

# Run full test suite + linting (default rake task)
bundle exec rake

# Run tests only
bundle exec rspec

# Run a single test file
bundle exec rspec spec/open_feature/sdk/client_spec.rb

# Run a specific test by line number
bundle exec rspec spec/open_feature/sdk/client_spec.rb:40

# Lint (StandardRB with performance plugin)
bundle exec rake standard

# Auto-fix lint issues
bundle exec standardrb --fix
```

## Architecture

Entry point: `require 'open_feature/sdk'` — the `OpenFeature::SDK` module delegates all method calls to `API.instance` (Singleton) via `method_missing`.

### Core Components

- **API** (`lib/open_feature/sdk/api.rb`) — Singleton orchestrator. Manages providers (global or domain-scoped), builds clients, stores API-level evaluation context, and registers event handlers.
- **Configuration** (`lib/open_feature/sdk/configuration.rb`) — Thread-safe provider storage. Handles provider lifecycle (init/shutdown), domain-scoped provider mapping, and event dispatching. Uses Mutex for all shared state.
- **Client** (`lib/open_feature/sdk/client.rb`) — Flag evaluation interface. Uses `class_eval` metaprogramming to generate 12 typed methods: `fetch_{boolean,string,number,integer,float,object}_value` and `fetch_*_details` variants. Merges evaluation contexts (API + client + invocation).
- **EvaluationContext** (`lib/open_feature/sdk/evaluation_context.rb`) — Key-value targeting data with a special `targeting_key`. Supports merging with precedence: invocation > client > API.

### Provider System

- **Provider interface** — Must implement 6 `fetch_*_value` methods, optional `init(evaluation_context)` and `shutdown`. Returns `ResolutionDetails`.
- **EventEmitter** (`lib/open_feature/sdk/provider/event_emitter.rb`) — Mixin that providers include to emit lifecycle events.
- **Built-in providers**: `NoOpProvider` (default), `InMemoryProvider` (testing/examples).
- **Provider states**: `NOT_READY → READY`, with `ERROR`, `FATAL`, `STALE` transitions. Tracked per-instance via `ProviderStateRegistry` using `object_id`.
- **Initialization modes**: `set_provider` (async, background thread) or `set_provider_and_wait` (sync, raises `ProviderInitializationError` on failure).

### Event System

- **EventDispatcher** (`lib/open_feature/sdk/event_dispatcher.rb`) — Thread-safe pub-sub. Handlers called outside mutex to prevent deadlocks. Supports API-level and client-level handlers.
- **ProviderEvent** constants: `PROVIDER_READY`, `PROVIDER_ERROR`, `PROVIDER_STALE`, `PROVIDER_CONFIGURATION_CHANGED`.

## Test Structure

Tests in `spec/` split into two categories:
- `spec/specification/` — OpenFeature spec compliance tests, organized by requirement number (e.g., "Requirement 1.1.1")
- `spec/open_feature/` — Unit tests for individual components

Uses Timecop for time-sensitive tests (auto-reset after each test), SimpleCov for coverage.

## Conventions

- **Linter**: StandardRB (Ruby Standard Style) with `standard-performance` plugin, targeting Ruby 3.1
- **Commits**: Conventional Commits required for PR titles (enforced by CI)
- **Releases**: Automated via release-please; changelog auto-generated
- **Threading**: All shared mutable state must be Mutex-protected. Provider storage uses immutable reassignment (`@providers = @providers.dup.merge(...)`)
- **Structs for DTOs**: `EvaluationDetails`, `ResolutionDetails`, `ClientMetadata`, `ProviderMetadata` are `Struct`-based
