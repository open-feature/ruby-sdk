require_relative "provider/error_code"
require_relative "provider/reason"
require_relative "provider/resolution_details"
require_relative "provider/provider_metadata"

# Provider interfaces
require_relative "provider/event_handler"

# Provider implementations
require_relative "provider/no_op_provider"
require_relative "provider/in_memory_provider"

# Event system components
require_relative "provider_event"
require_relative "provider_state"
require_relative "event_emitter"
require_relative "event_to_state_mapper"
require_relative "provider_state_registry"

module OpenFeature
  module SDK
    module Provider
    end
  end
end
