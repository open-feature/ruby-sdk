# frozen_string_literal: true

require "simplecov"

require "open_feature/sdk"

require "markly"

require "debug"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.filter_run_when_matching :focus

  # ie for GitHub Actions
  # see https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
  if ENV["CI"] == "true"
    # force tty to get output, which Actions does support
    config.tty = true
  end
end
