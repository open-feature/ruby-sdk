# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

begin
  require "yard"
  YARD::Rake::YardocTask.new
rescue LoadError
  # YARD not available
end

desc "Run Cucumber Gherkin feature tests"
task :cucumber do
  sh "bundle exec cucumber"
end

task default: %i[spec standard]
