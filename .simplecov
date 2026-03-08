# frozen_string_literal: true

require "simplecov-cobertura"

SimpleCov.start do
  add_filter "/spec/"
  minimum_coverage 90
  if ENV["CI"] == "true"
    formatter SimpleCov::Formatter::CoberturaFormatter
  else
    formatter SimpleCov::Formatter::HTMLFormatter
  end
end
