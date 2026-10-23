# frozen_string_literal: true

require_relative "../sdk"

module OpenFeature
  module SDK
    # Spec 1.8.3: a separate require, so isolated instances are an explicit opt-in
    module Isolated
      # Spec 1.8.1: a new API that shares no state with the global one or other isolated APIs
      def self.create_api
        API.send(:new)
      end
    end
  end
end
