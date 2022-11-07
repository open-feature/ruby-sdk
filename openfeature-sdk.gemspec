# frozen_string_literal: true

require_relative "lib/openfeature/sdk/version"

Gem::Specification.new do |spec|
  spec.name = "openfeature-sdk"
  spec.version = OpenFeature::SDK::VERSION
  spec.authors = ["OpenFeature Authors"]
  spec.email = ["cncf-openfeature-contributors@lists.cncf.io"]

  spec.summary = "OpenFeature SDK for Ruby"
  spec.description = "Ruby SDK for an the specifications for the open standard of feature flag management"
  spec.homepage = "https://github.com/open-feature/openfeature-ruby"
  spec.license = "Apache-2.0'"
  spec.required_ruby_version = ">= 2.7.6"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/open-feature/openfeature-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/open-feature/openfeature-ruby/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/open-feature/openfeature-ruby/issues"
  spec.metadata["documentation_uri"] = "https://github.com/open-feature/openfeature-ruby/README.md"

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

  spec.add_dependency "sorbet-runtime", "~> 0.5.10539"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12.0"
  spec.add_development_dependency "rubocop", "~> 1.37.1"
  spec.add_development_dependency "sorbet", "~> 0.5.10539"
  spec.metadata["rubygems_mfa_required"] = "true"
end
