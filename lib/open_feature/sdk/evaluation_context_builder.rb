module OpenFeature
  module SDK
    # Used to combine evaluation contexts from different sources
    class EvaluationContextBuilder
      def call(api_context:, client_context:, invocation_context:)
        available_contexts = [api_context, client_context, invocation_context].compact

        return nil if available_contexts.empty?

        available_contexts.reduce(EvaluationContext.new) do |built_context, context|
          built_context.merge(context)
        end
      end
    end
  end
end
