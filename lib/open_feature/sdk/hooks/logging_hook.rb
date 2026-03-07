# frozen_string_literal: true

module OpenFeature
  module SDK
    module Hooks
      class LoggingHook
        include Hook

        def initialize(logger: nil, include_evaluation_context: false)
          @logger = logger
          @include_evaluation_context = include_evaluation_context
        end

        def before(hook_context:, hints:)
          logger&.debug { build_before_message(hook_context) }
          nil
        end

        def after(hook_context:, evaluation_details:, hints:)
          logger&.debug { build_after_message(hook_context, evaluation_details) }
          nil
        end

        def error(hook_context:, exception:, hints:)
          logger&.error { build_error_message(hook_context, exception) }
          nil
        end

        private

        def logger
          @logger || OpenFeature::SDK.configuration.logger
        end

        def build_before_message(hook_context)
          parts = base_parts("before", hook_context)
          parts << "evaluation_context=#{format_context(hook_context.evaluation_context)}" if @include_evaluation_context
          parts.join(" ")
        end

        def build_after_message(hook_context, evaluation_details)
          parts = base_parts("after", hook_context)
          parts << "reason=#{evaluation_details.reason}" if evaluation_details.reason
          parts << "variant=#{evaluation_details.variant}" if evaluation_details.variant
          parts << "value=#{evaluation_details.value}"
          parts << "evaluation_context=#{format_context(hook_context.evaluation_context)}" if @include_evaluation_context
          parts.join(" ")
        end

        def build_error_message(hook_context, exception)
          parts = base_parts("error", hook_context)
          parts << "error_code=#{exception.respond_to?(:error_code) ? exception.error_code : Provider::ErrorCode::GENERAL}"
          parts << "error_message=#{exception.message}"
          parts << "evaluation_context=#{format_context(hook_context.evaluation_context)}" if @include_evaluation_context
          parts.join(" ")
        end

        def base_parts(stage, hook_context)
          domain = hook_context.client_metadata&.domain
          provider_name = hook_context.provider_metadata&.name
          [
            "stage=#{stage}",
            "domain=#{domain}",
            "provider_name=#{provider_name}",
            "flag_key=#{hook_context.flag_key}",
            "default_value=#{hook_context.default_value}"
          ]
        end

        def format_context(evaluation_context)
          return "" unless evaluation_context
          fields = evaluation_context.fields.dup
          fields["targeting_key"] = evaluation_context.targeting_key if evaluation_context.targeting_key
          fields.map { |k, v| "#{k}=#{v}" }.join(", ")
        end
      end
    end
  end
end
