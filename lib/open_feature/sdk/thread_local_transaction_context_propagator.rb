# frozen_string_literal: true

module OpenFeature
  module SDK
    class ThreadLocalTransactionContextPropagator
      include TransactionContextPropagator

      THREAD_KEY = :openfeature_transaction_context

      def set_transaction_context(evaluation_context)
        Thread.current[THREAD_KEY] = evaluation_context
      end

      def get_transaction_context
        Thread.current[THREAD_KEY]
      end
    end
  end
end
