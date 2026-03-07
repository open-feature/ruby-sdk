# frozen_string_literal: true

module OpenFeature
  module SDK
    module TransactionContextPropagator
      def set_transaction_context(evaluation_context)
        raise NotImplementedError
      end

      def get_transaction_context
        raise NotImplementedError
      end
    end
  end
end
