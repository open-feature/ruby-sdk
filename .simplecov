# frozen_string_literal: true

require "simplecov-cobertura"

SimpleCov.start do
  add_filter "/spec/"
  if ENV["CI"] == "true"
    formatter SimpleCov::Formatter::CoberturaFormatter
  else
    formatter SimpleCov::Formatter::HTMLFormatter
  end
end
