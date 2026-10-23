# frozen_string_literal: true

require_relative "../frozen_copy"

module OpenFeature
  module SDK
    module Provider
      EMPTY_FLAG_METADATA = {}.freeze

      ResolutionDetails = Struct.new(:value, :reason, :variant, :error_code, :error_message, :flag_metadata, keyword_init: true) do
        def flag_metadata
          FrozenCopy.of(self[:flag_metadata] || EMPTY_FLAG_METADATA)
        end
      end
    end
  end
end
