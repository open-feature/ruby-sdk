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

      attr_reader :metadata

      attr_accessor :hooks, :evaluation_context

      def initialize(provider: nil, domain: nil, evaluation_context: nil)
        @provider = provider
        @metadata = ClientMetadata.new(domain:)
        @evaluation_context = evaluation_context
        @hooks = []
      end

      def add_hooks(*new_hooks)
        @hooks.concat(new_hooks.flatten)
      end

      def provider_status
        OpenFeature::SDK.configuration.provider_state(resolve_provider)
      end

      def add_handler(event_type, handler = nil, &block)
        actual_handler = handler || block
        OpenFeature::SDK.configuration.add_client_handler(self, event_type, actual_handler)
      end

      def remove_handler(event_type, handler = nil, &block)
        actual_handler = handler || block
        OpenFeature::SDK.configuration.remove_client_handler(self, event_type, actual_handler)
      end

      # Tracking API (spec 6.1.1.1) — dynamic-context paradigm
      #
      # Records a tracking event. If the provider does not implement
      # tracking, this is a no-op (spec 6.1.4).
      def track(tracking_event_name, evaluation_context: nil, tracking_event_details: nil)
        provider = resolve_provider
        return unless provider.respond_to?(:track)

        built_context = build_evaluation_context(evaluation_context)

        provider.track(tracking_event_name, evaluation_context: built_context, tracking_event_details: tracking_event_details)
      rescue StandardError, NotImplementedError
        nil
      end

      RESULT_TYPE.each do |result_type|
        SUFFIXES.each do |suffix|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def fetch_#{result_type}_#{suffix}(flag_key:, default_value:, evaluation_context: nil, hooks: [], hook_hints: nil)
              validate_default_value_type(:#{result_type}, default_value)
              evaluation_details = fetch_details(type: :#{result_type}, flag_key:, default_value:, evaluation_context:, invocation_hooks: hooks, hook_hints: hook_hints)
              #{"evaluation_details.value" if suffix == :value}
            end
          RUBY
        end
      end

      private

      def fetch_details(type:, flag_key:, default_value:, evaluation_context: nil, invocation_hooks: [], hook_hints: nil)
        provider = resolve_provider
        built_context = build_evaluation_context(evaluation_context)

        # Assemble ordered hooks: API → Client → Invocation → Provider (spec 4.4.2)
        provider_hooks = provider.respond_to?(:hooks) ? Array(provider.hooks) : []
        ordered_hooks = [*OpenFeature::SDK.hooks, *@hooks, *invocation_hooks, *provider_hooks]

        # Short-circuit NOT_READY/FATAL providers (required by evaluation_v2.feature)
        short_circuit_code = nil
        if OpenFeature::SDK.configuration.provider_tracked?(provider)
          short_circuit_code = short_circuit_error_code(OpenFeature::SDK.configuration.provider_state(provider))
        end

        # Fast path: skip hook ceremony when no hooks are registered
        if ordered_hooks.empty?
          if short_circuit_code
            resolution = Provider::ResolutionDetails.new(
              value: default_value,
              error_code: short_circuit_code,
              reason: Provider::Reason::ERROR
            )
            return EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution)
          end

          return evaluate_flag(provider: provider, type: type, flag_key: flag_key, default_value: default_value, evaluation_context: built_context)
        end

        hook_context = Hooks::HookContext.new(
          flag_key: flag_key,
          flag_value_type: type,
          default_value: default_value,
          evaluation_context: built_context,
          client_metadata: @metadata,
          provider_metadata: provider.respond_to?(:metadata) ? provider.metadata : nil
        )

        hints = if hook_hints.is_a?(Hooks::Hints)
          hook_hints
        elsif hook_hints
          Hooks::Hints.new(hook_hints)
        else
          EMPTY_HINTS
        end

        executor = Hooks::HookExecutor.new(logger: OpenFeature::SDK.configuration.logger)

        if short_circuit_code
          resolution = Provider::ResolutionDetails.new(
            value: default_value,
            error_code: short_circuit_code,
            reason: Provider::Reason::ERROR
          )
          evaluation_details = EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution)
          executor.run_short_circuit(ordered_hooks: ordered_hooks, hook_context: hook_context, hints: hints, evaluation_details: evaluation_details)
          evaluation_details
        else
          executor.execute(ordered_hooks: ordered_hooks, hook_context: hook_context, hints: hints) do |hctx|
            evaluate_flag(provider: provider, type: type, flag_key: flag_key, default_value: default_value, evaluation_context: hctx.evaluation_context)
          end
        end
      rescue StandardError, NotImplementedError => e
        # Spec 1.4.10 and 1.4.11: report through the details, never raise or log. NotImplementedError is the abstract-method idiom.
        resolution = Provider::ResolutionDetails.new(
          value: default_value,
          error_code: EvaluationError.code_for(e),
          reason: Provider::Reason::ERROR,
          error_message: e.message
        )
        EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution)
      end

      def evaluate_flag(provider:, type:, flag_key:, default_value:, evaluation_context:)
        resolution_details = provider.send(
          :"fetch_#{type}_value",
          flag_key: flag_key,
          default_value: default_value,
          evaluation_context: evaluation_context
        )

        if resolution_details.error_code || TYPE_CLASS_MAP[type].none? { |klass| resolution_details.value.is_a?(klass) }
          resolution_details.value = default_value
          resolution_details.error_code ||= Provider::ErrorCode::TYPE_MISMATCH
          resolution_details.reason = Provider::Reason::ERROR
          resolution_details.variant = nil
        end

        EvaluationDetails.new(flag_key: flag_key, resolution_details: resolution_details)
      end

      # Callers resolve once per operation, so a rebinding mid-evaluation can't mix two providers.
      # The fallback NoOp is never registered: untracked, so not short-circuited, and its status reads NOT_READY.
      def resolve_provider
        @provider || OpenFeature::SDK.configuration.provider(domain: @metadata.domain) || (@fallback_provider ||= Provider::NoOpProvider.new)
      end

      def short_circuit_error_code(state)
        case state
        when ProviderState::NOT_READY then Provider::ErrorCode::PROVIDER_NOT_READY
        when ProviderState::FATAL then Provider::ErrorCode::PROVIDER_FATAL
        end
      end

      def build_evaluation_context(invocation_context)
        propagator = OpenFeature::SDK.configuration.transaction_context_propagator
        transaction_context = propagator&.get_transaction_context

        EvaluationContextBuilder.new.call(
          api_context: OpenFeature::SDK.evaluation_context,
          transaction_context: transaction_context,
          client_context: evaluation_context,
          invocation_context: invocation_context
        )
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
