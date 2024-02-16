module OpenFeature
  module SDK
    module Provider
      ResolutionDetails = Struct.new(:value, :reason, :variant, :error_code, :error_message, :flag_metadata)
    end
  end
end
