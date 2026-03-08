# frozen_string_literal: true

# Example: OpenFeature integration with Ruby on Rails
#
# This file demonstrates how you might integrate OpenFeature into a Rails app.
# It is not runnable standalone — it shows patterns for use in a Rails context.

# config/initializers/openfeature.rb
#
# OpenFeature::SDK.configure do |config|
#   config.set_provider(YourProvider.new)
#
#   # Set global context with server-level info
#   config.evaluation_context = OpenFeature::SDK::EvaluationContext.new(
#     "environment" => Rails.env,
#     "service" => "my-rails-app"
#   )
#
#   # Use thread-local transaction context for per-request data
#   config.set_transaction_context_propagator(
#     OpenFeature::SDK::ThreadLocalTransactionContextPropagator.new
#   )
# end

# app/middleware/openfeature_context_middleware.rb
#
# class OpenFeatureContextMiddleware
#   def initialize(app)
#     @app = app
#   end
#
#   def call(env)
#     request = ActionDispatch::Request.new(env)
#     OpenFeature::SDK.set_transaction_context(
#       OpenFeature::SDK::EvaluationContext.new(
#         targeting_key: request.session[:user_id]&.to_s,
#         "ip" => request.remote_ip,
#         "user_agent" => request.user_agent
#       )
#     )
#     @app.call(env)
#   end
# end

# app/controllers/application_controller.rb
#
# class ApplicationController < ActionController::Base
#   private
#
#   def feature_client
#     @feature_client ||= OpenFeature::SDK.build_client(domain: "web")
#   end
#
#   def feature_enabled?(flag_key)
#     feature_client.fetch_boolean_value(flag_key: flag_key, default_value: false)
#   end
# end
