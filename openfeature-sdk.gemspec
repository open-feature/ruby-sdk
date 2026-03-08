# frozen_string_literal: true

require_relative "lib/open_feature/sdk/version"

Gem::Specification.new do |spec|
  spec.name = "openfeature-sdk"
  spec.version = OpenFeature::SDK::VERSION
  spec.authors = ["OpenFeature Authors"]
  spec.email = ["cncf-openfeature-contributors@lists.cncf.io"]

  spec.summary = "OpenFeature SDK for Ruby"
  spec.description = "Ruby SDK for the OpenFeature specification, an open standard for feature flag management"
  spec.homepage = "https://github.com/open-feature/ruby-sdk"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/open-feature/ruby-sdk"
  spec.metadata["changelog_uri"] = "https://github.com/open-feature/ruby-sdk/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/open-feature/ruby-sdk/issues"
  spec.metadata["documentation_uri"] = "https://github.com/open-feature/ruby-sdk#readme"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
