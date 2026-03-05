# frozen_string_literal: true

module OpenFeature
  module SDK
    # TODO: Write documentation
    #
    class Client
      TYPE_CLASS_MAP = {
        boolean: [TrueClass, FalseClass],
        string: [String],
        number: [Numeric],
        integer: [Integer],
        float: [Float],
        object: [Array, Hash]
      }.freeze
      RESULT_TYPE = TYPE_CLASS_MAP.keys.freeze
      SUFFIXES = %i[value details].freeze
      EMPTY_HINTS = Hooks::Hints.new.freeze

      attr_reader :metadata, :evaluation_context

      attr_accessor :hooks

      def initialize(provider:, domain: nil, evaluation_context: nil)
        @provider = provider
        @metadata = ClientMetadata.new(domain:)
        @evaluation_context = evaluation_context
        @hooks = []
      end

      def provider_status
        OpenFeature::SDK.configuration.provider_state(@provider)
      end

      def add_handler(event_type, handler = nil, &block)
        actual_handler = handler || block
        OpenFeature::SDK.configuration.add_client_handler(self, event_type, actual_handler)
      end

      def remove_handler(event_type, handler = nil, &block)
        actual_handler = handler || block
        OpenFeature::SDK.configuration.remove_client_handler(self, event_type, actual_handler)
      end

      RESULT_TYPE.each do |result_type|
        SUFFIXES.each do |suffix|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def fetch_#{result_type}_#{suffix}(flag_key:, default_value:, evaluation_context: nil, hooks: [], hook_hints: nil)
              evaluation_details = fetch_details(type: :#{result_type}, flag_key:, default_value:, evaluation_context:, invocation_hooks: hooks, hook_hints: hook_hints)
              #{"evaluation_details.value" if suffix == :value}
            end
          RUBY
        end
      end

      private

      def fetch_details(type:, flag_key:, default_value:, evaluation_context: nil, invocation_hooks: [], hook_hints: nil)
        validate_default_value_type(type, default_value)

        state = provider_status
        if OpenFeature::SDK.configuration.provider_tracked?(@provider) && state == ProviderState::NOT_READY
          resolution = Provider::ResolutionDetails.new(
            value: default_value,
            error_code: Provider::ErrorCode::PROVIDER_NOT_READY,
            reason: Provider::Reason::ERROR
          )
          return EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution)
        elsif OpenFeature::SDK.configuration.provider_tracked?(@provider) && state == ProviderState::FATAL
          resolution = Provider::ResolutionDetails.new(
            value: default_value,
            error_code: Provider::ErrorCode::PROVIDER_FATAL,
            reason: Provider::Reason::ERROR
          )
          return EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution)
        end

        built_context = EvaluationContextBuilder.new.call(
          api_context: OpenFeature::SDK.evaluation_context,
          client_context: self.evaluation_context,
          invocation_context: evaluation_context
        )

        # Assemble ordered hooks: API → Client → Invocation → Provider (spec 4.4.2)
        provider_hooks = @provider.respond_to?(:hooks) ? Array(@provider.hooks) : []
        ordered_hooks = [*OpenFeature::SDK.hooks, *@hooks, *invocation_hooks, *provider_hooks]

        # Fast path: skip hook ceremony when no hooks are registered
        if ordered_hooks.empty?
          return evaluate_flag(type: type, flag_key: flag_key, default_value: default_value, evaluation_context: built_context)
        end

        hook_context = Hooks::HookContext.new(
          flag_key: flag_key,
          flag_value_type: type,
          default_value: default_value,
          evaluation_context: built_context,
          client_metadata: @metadata,
          provider_metadata: @provider.respond_to?(:metadata) ? @provider.metadata : nil
        )

        hints = if hook_hints.is_a?(Hooks::Hints)
          hook_hints
        elsif hook_hints
          Hooks::Hints.new(hook_hints)
        else
          EMPTY_HINTS
        end

        executor = Hooks::HookExecutor.new(logger: OpenFeature::SDK.configuration.logger)
        executor.execute(ordered_hooks: ordered_hooks, hook_context: hook_context, hints: hints) do |hctx|
          evaluate_flag(type: type, flag_key: flag_key, default_value: default_value, evaluation_context: hctx.evaluation_context)
        end
      end

      def evaluate_flag(type:, flag_key:, default_value:, evaluation_context:)
        resolution_details = @provider.send(
          :"fetch_#{type}_value",
          flag_key: flag_key,
          default_value: default_value,
          evaluation_context: evaluation_context
        )

        if TYPE_CLASS_MAP[type].none? { |klass| resolution_details.value.is_a?(klass) }
          resolution_details.value = default_value
          resolution_details.error_code = Provider::ErrorCode::TYPE_MISMATCH
          resolution_details.reason = Provider::Reason::ERROR
        end

        EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution_details)
      end

      def validate_default_value_type(type, default_value)
        expected_classes = TYPE_CLASS_MAP[type]
        unless expected_classes.any? { |klass| default_value.is_a?(klass) }
          expected_types = expected_classes.map(&:name).join(" or ")
          actual_type = default_value.class.name
          raise ArgumentError, "Default value for #{type} must be #{expected_types}, got #{actual_type}"
        end
      end
    end
  end
end
