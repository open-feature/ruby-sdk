# frozen_string_literal: true

module OpenFeature
  module SDK
    # Provider mirroring contrib overrides: init(evaluation_context) without domain.
    class LegacyInitProvider < Provider::InMemoryProvider
      attr_reader :init_calls, :last_context

      def init(evaluation_context = nil)
        @init_calls = (@init_calls || 0) + 1
        @last_context = evaluation_context
      end
    end
  end
end
