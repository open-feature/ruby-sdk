# frozen_string_literal: true

module OpenFeature
  module SDK
    class ThreadLocalTransactionContextPropagator
      include TransactionContextPropagator

      # One context per propagator under this key, so separate APIs never share one (spec 1.8.2)
      # while resetting the key still clears them all
      THREAD_KEY = :openfeature_transaction_context

      def set_transaction_context(evaluation_context)
        contexts = Thread.current[THREAD_KEY]
        contexts = Thread.current[THREAD_KEY] = {}.compare_by_identity unless contexts.is_a?(Hash)
        evaluation_context.nil? ? contexts.delete(self) : contexts[self] = evaluation_context
      end

      def get_transaction_context
        contexts = Thread.current[THREAD_KEY]
        contexts[self] if contexts.is_a?(Hash)
      end
    end
  end
end
