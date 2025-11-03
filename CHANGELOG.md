# Changelog

## [0.4.1](https://github.com/open-feature/ruby-sdk/compare/v0.4.0...v0.4.1) (2025-11-03)


### Features

* Add runtime type validation for default values in flag evaluation methods ([#194](https://github.com/open-feature/ruby-sdk/issues/194)) ([dc56c76](https://github.com/open-feature/ruby-sdk/commit/dc56c76f987c16b22a284513b7d0f383d38a0198))
* Add setProviderAndWait method for blocking provider initialization ([#200](https://github.com/open-feature/ruby-sdk/issues/200)) ([d92eabc](https://github.com/open-feature/ruby-sdk/commit/d92eabcb54335e21522cea0d6b10be3e842ce8e2))

## [0.4.0](https://github.com/open-feature/ruby-sdk/compare/v0.3.1...v0.4.0) (2024-06-13)


### ⚠ BREAKING CHANGES

* Use strings from spec for error and reason enums ([#131](https://github.com/open-feature/ruby-sdk/issues/131))

### Features

* add hook hints ([#135](https://github.com/open-feature/ruby-sdk/issues/135)) ([51155a7](https://github.com/open-feature/ruby-sdk/commit/51155a7d9cd2c28b38accb9d9b49018bd4868040))
* Use strings from spec for error and reason enums ([#131](https://github.com/open-feature/ruby-sdk/issues/131)) ([cb2a4cd](https://github.com/open-feature/ruby-sdk/commit/cb2a4cd54059ffe7ed3484be6705ca2a9d590c1a))


### Bug Fixes

* synchronize provider registration ([#136](https://github.com/open-feature/ruby-sdk/issues/136)) ([1ff6fd0](https://github.com/open-feature/ruby-sdk/commit/1ff6fd0c3732e9e074c8b30cbe4164a67286b0a4))

## [0.3.1](https://github.com/open-feature/ruby-sdk/compare/v0.3.0...v0.3.1) (2024-04-22)


### Features

* add integer and float specific resolver methods ([#124](https://github.com/open-feature/ruby-sdk/issues/124)) ([eea9d17](https://github.com/open-feature/ruby-sdk/commit/eea9d17e5892064cec9d81bb0ef452e7e1761764))

## [0.3.0](https://github.com/open-feature/ruby-sdk/compare/v0.2.1...v0.3.0) (2024-04-05)


### ⚠ BREAKING CHANGES

* Add `EvaluationContext` helpers and context merging to flag evaluation ([#119](https://github.com/open-feature/ruby-sdk/issues/119))
* Separate `Client` and `Provider` metadata, add client creation tests ([#116](https://github.com/open-feature/ruby-sdk/issues/116))

### Features

* Add `EvaluationContext` helpers and context merging to flag evaluation ([#119](https://github.com/open-feature/ruby-sdk/issues/119)) ([34e4795](https://github.com/open-feature/ruby-sdk/commit/34e47956d66e0c6763f58c818461aa52f628bd21))
* Add evaluation context based on requirement 3.1 ([#114](https://github.com/open-feature/ruby-sdk/issues/114)) ([f8e016f](https://github.com/open-feature/ruby-sdk/commit/f8e016f1cf7bf1ca7fddce7a41efdeb4d3d522c1))
* Flag Evaluation Requirement 1.1.4 and 1.1.5 and Provider Requirement 2.1.1 ([#112](https://github.com/open-feature/ruby-sdk/issues/112)) ([aac74b1](https://github.com/open-feature/ruby-sdk/commit/aac74b1e80a4b3e69983e55cf5c75b9cee37b71b))


### Code Refactoring

* Separate `Client` and `Provider` metadata, add client creation tests ([#116](https://github.com/open-feature/ruby-sdk/issues/116)) ([f028c39](https://github.com/open-feature/ruby-sdk/commit/f028c398db3e2317847fe7e7bcbe6bbe96bb0b1c))

## [0.2.1](https://github.com/open-feature/ruby-sdk/compare/v0.2.0...v0.2.1) (2024-03-29)


### Bug Fixes

* Add domain to build_client ([#109](https://github.com/open-feature/ruby-sdk/issues/109)) ([56ccf17](https://github.com/open-feature/ruby-sdk/commit/56ccf17ec340df0ea14a72ea7379c51dbb9d7b13))

## [0.2.0](https://github.com/open-feature/ruby-sdk/compare/v0.1.1...v0.2.0) (2024-03-09)


### ⚠ BREAKING CHANGES

* Implement Requirement 1.1.3 ([#80](https://github.com/open-feature/ruby-sdk/issues/80))
* rename top-level lib folder to `open_feature` ([#90](https://github.com/open-feature/ruby-sdk/issues/90))
* Drop Ruby 2.7 and 3.0, add Ruby 3.3 ([#91](https://github.com/open-feature/ruby-sdk/issues/91))

### Features

* adds `InMemoryProvider` ([#102](https://github.com/open-feature/ruby-sdk/issues/102)) ([25680a4](https://github.com/open-feature/ruby-sdk/commit/25680a40b0955ee66da256f23f7078655754a4b6))
* Implement Requirement 1.1.2 ([#78](https://github.com/open-feature/ruby-sdk/issues/78)) ([8cea7d0](https://github.com/open-feature/ruby-sdk/commit/8cea7d0cefc31ddeb2095ac60c40db3b038b02c5))
* Implement Requirement 1.1.3 ([#80](https://github.com/open-feature/ruby-sdk/issues/80)) ([bc65e7a](https://github.com/open-feature/ruby-sdk/commit/bc65e7a2754d736e858a856fd39118940c63ee41))
* Updates to `Provider` module in preparation for `InMemoryProvider` ([#99](https://github.com/open-feature/ruby-sdk/issues/99)) ([2d89570](https://github.com/open-feature/ruby-sdk/commit/2d89570b2ebace61bcb261cfcb54b2724a4a75f7))


### Miscellaneous Chores

* Drop Ruby 2.7 and 3.0, add Ruby 3.3 ([#91](https://github.com/open-feature/ruby-sdk/issues/91)) ([51cd3a1](https://github.com/open-feature/ruby-sdk/commit/51cd3a1801e589f9049bffd7349d56bb6d32d05e))
* rename top-level lib folder to `open_feature` ([#90](https://github.com/open-feature/ruby-sdk/issues/90)) ([e1a9a01](https://github.com/open-feature/ruby-sdk/commit/e1a9a018e18cb62acedd1b5cd5a00ad3ecb4321a))

## [0.1.1](https://github.com/open-feature/ruby-sdk/compare/v0.1.0...v0.1.1) (2023-09-13)


### Bug Fixes

* OpenFeature::SDK::Configuration uses concurrent-ruby gem even though it doesn't depend on it ([#61](https://github.com/open-feature/ruby-sdk/issues/61)) ([c3c1222](https://github.com/open-feature/ruby-sdk/commit/c3c12226a21e43d62358562f4008a4a44a10e72b))

## [0.1.0](https://github.com/open-feature/ruby-sdk/compare/v0.0.3...v0.1.0) (2022-12-15)


### Features

* Add client object ([#34](https://github.com/open-feature/ruby-sdk/issues/34)) ([92f8d0d](https://github.com/open-feature/ruby-sdk/commit/92f8d0d4bf693bf74d0f076621f3453f11d4ca65))
* OpenFeature::SDK.configure ([#41](https://github.com/open-feature/ruby-sdk/issues/41)) ([7587799](https://github.com/open-feature/ruby-sdk/commit/75877997dcb49aeb38a4969734df87b2845e1e6a))
* **spec:** Add API implementation ([#32](https://github.com/open-feature/ruby-sdk/issues/32)) ([d6b0922](https://github.com/open-feature/ruby-sdk/commit/d6b0922a54e9cb714c44dfe58ddab01356f6916b))

## [0.0.3](https://github.com/open-feature/ruby-sdk/compare/v0.0.2...v0.0.3) (2022-11-11)


### Bug Fixes

* Update Gemfile.lock ([#25](https://github.com/open-feature/ruby-sdk/issues/25)) ([6a1f789](https://github.com/open-feature/ruby-sdk/commit/6a1f789bd016a6b1d961a8ce61d3366116d4e3e5))
* Update release please ([#24](https://github.com/open-feature/ruby-sdk/issues/24)) ([457c326](https://github.com/open-feature/ruby-sdk/commit/457c3262131c55deeb5719d94ee18ac8591488b1))
* Update release please ([#27](https://github.com/open-feature/ruby-sdk/issues/27)) ([ca98386](https://github.com/open-feature/ruby-sdk/commit/ca983861fd50388a05bca60b1483ed65fb8aedb5))

## [0.0.2](https://github.com/open-feature/ruby-sdk/compare/v0.0.1...v0.0.2) (2022-11-11)


### Bug Fixes

* Update gemspec to remove mfa ([#22](https://github.com/open-feature/ruby-sdk/issues/22)) ([ea5250d](https://github.com/open-feature/ruby-sdk/commit/ea5250dfd16598a13a1a6542e44f4fa3664f251e))
* Update README with support matrix ([#18](https://github.com/open-feature/ruby-sdk/issues/18)) ([2f79a87](https://github.com/open-feature/ruby-sdk/commit/2f79a87320cff30835081599f21f544d2d4e52cf))
* Update release please ([#20](https://github.com/open-feature/ruby-sdk/issues/20)) ([9ce28b5](https://github.com/open-feature/ruby-sdk/commit/9ce28b51b295f21a58ffd9812de794b3d3f1803b))

## [Unreleased]
