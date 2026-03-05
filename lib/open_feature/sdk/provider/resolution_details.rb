# frozen_string_literal: true

module OpenFeature
  module SDK
    module Provider
      EMPTY_FLAG_METADATA = {}.freeze

      ResolutionDetails = Struct.new(:value, :reason, :variant, :error_code, :error_message, :flag_metadata, keyword_init: true) do
        def flag_metadata
          raw = self[:flag_metadata]
          if raw.nil?
            EMPTY_FLAG_METADATA
          elsif raw.frozen?
            raw
          else
            raw.freeze
          end
        end
      end
    end
  end
end
