# frozen_string_literal: true

require_relative "api"
require_relative "provider_initialization_error"
require_relative "evaluation_error"
require_relative "event_dispatcher"
require_relative "provider_event"
require_relative "provider_state_registry"
require_relative "provider/event_emitter"

module OpenFeature
  module SDK
    # Represents the configuration object for the global API where <tt>Provider</tt>, <tt>Hook</tt>,
    # and <tt>EvaluationContext</tt> are configured.
    # This class is not meant to be interacted with directly but instead through the <tt>OpenFeature::SDK.configure</tt>
    # method
    class Configuration
      extend Forwardable

      attr_accessor :evaluation_context, :hooks, :transaction_context_propagator
      attr_reader :logger

      # One per registration; +done+ is closed once init finishes, so waiters can pop on it
      InitAttempt = Struct.new(:state, :error, :done, :thread)
      private_constant :InitAttempt

      def initialize
        @hooks = []
        @providers = {}
        @init_attempts = {}.compare_by_identity
        @legacy_warned = Set.new.compare_by_identity
        @provider_mutex = Mutex.new
        @logger = nil
        @event_dispatcher = EventDispatcher.new(@logger)
        @provider_state_registry = ProviderStateRegistry.new
        @client_handlers = {}
        @client_handlers_mutex = Mutex.new
        @dispatch_key = :"openfeature_dispatch_#{object_id}"
      end

      def add_hooks(*new_hooks)
        @hooks.concat(new_hooks.flatten)
      end

      def provider(domain: nil)
        @providers[domain] || @providers[nil]
      end

      def logger=(new_logger)
        @logger = new_logger
        @event_dispatcher.logger = new_logger if @event_dispatcher
      end

      def add_handler(event_type, handler)
        @event_dispatcher.add_handler(event_type, handler)
        run_immediate_handler(event_type, handler, nil)
      end

      def remove_handler(event_type, handler)
        @event_dispatcher.remove_handler(event_type, handler)
      end

      # @api private
      def add_client_handler(client, event_type, handler)
        @event_dispatcher.validate_handler!(event_type, handler)

        @client_handlers_mutex.synchronize do
          @client_handlers[client] ||= Hash.new { |h, k| h[k] = [] }
          @client_handlers[client][event_type] << handler
        end

        run_immediate_handler(event_type, handler, client)
      end

      # @api private
      def remove_client_handler(client, event_type, handler)
        @client_handlers_mutex.synchronize do
          return unless @client_handlers[client]
          handlers = @client_handlers[client][event_type]
          handlers&.delete(handler)
        end
      end

      def set_provider(provider, domain: nil)
        set_provider_internal(provider, domain: domain, wait_for_init: false)
      end

      def set_provider_and_wait(provider, domain: nil)
        set_provider_internal(provider, domain: domain, wait_for_init: true)
      end

      def provider_state(provider)
        @provider_state_registry.get_state(provider)
      end

      def provider_tracked?(provider)
        @provider_state_registry.tracked?(provider)
      end

      def shutdown
        # Unbind before shutting down so events that arrive mid-shutdown are dropped
        providers_to_shutdown = @provider_mutex.synchronize do
          bound = @providers.values.uniq(&:object_id)
          @providers = {}
          bound
        end

        providers_to_shutdown.each do |prov|
          # Spec 1.7.6: Set provider state to NOT_READY before shutdown
          @provider_state_registry.set_initial_state(prov, ProviderState::NOT_READY)
          prov.send(:detach) if prov.is_a?(Provider::EventEmitter)
          prov.shutdown if prov.respond_to?(:shutdown)
        rescue => e
          @logger&.warn("Error shutting down provider #{prov&.class&.name || "unknown"}: #{e.message}")
        end

        reset
      end

      private

      def reset
        @event_dispatcher.clear_all_handlers
        @client_handlers_mutex.synchronize do
          @client_handlers.clear
        end
        @provider_state_registry.clear
        @provider_mutex.synchronize do
          @providers.clear
          @init_attempts.each_value { |attempt| abandon_init_attempt(attempt) }
          @init_attempts.clear
          @legacy_warned.clear
        end
        @hooks.clear
        @evaluation_context = nil
        @transaction_context_propagator = nil
      end

      def set_provider_internal(provider, domain:, wait_for_init:)
        # Capture evaluation context before acquiring mutex to prevent race conditions
        context_for_init = @evaluation_context

        old_provider = nil
        attempt = nil
        needs_init = false
        init_thread = nil
        needs_shutdown = false

        # Provider code runs before taking the lock: it may call back into the SDK
        scoped = domain_scoped?(provider)
        has_init = provider.respond_to?(:init)
        legacy = has_init && !emits_lifecycle_events?(provider)
        warn_legacy_provider(provider) if legacy

        @provider_mutex.synchronize do
          validate_domain_scoped_binding!(provider, domain, scoped)

          old_provider = @providers[domain]

          new_providers = @providers.dup
          new_providers[domain] = provider
          @providers = new_providers

          # Spec 1.1.2.2: initialize once per registration; a failed init is retried on the next set
          attempt = @init_attempts[provider]
          needs_init = attempt.nil? || attempt.state == :failed

          if needs_init
            attempt = @init_attempts[provider] = InitAttempt.new(:running, nil, Thread::Queue.new)
            @provider_state_registry.set_initial_state(provider)
            provider.send(:attach, self) if provider.is_a?(Provider::EventEmitter)
          end

          # Spec 1.1.2.3: Only shutdown old provider if it's no longer bound to any domain
          if old_provider && !old_provider.equal?(provider)
            needs_shutdown = !provider_bound?(old_provider)
            if needs_shutdown
              abandon_init_attempt(@init_attempts.delete(old_provider))
              @provider_state_registry.remove_provider(old_provider)
              old_provider.send(:detach) if old_provider.is_a?(Provider::EventEmitter)
            end
          end
        end

        # Shutdown old provider outside mutex to avoid blocking other operations
        if needs_shutdown
          begin
            old_provider.shutdown if old_provider.respond_to?(:shutdown)
          rescue => e
            @logger&.warn("Error shutting down previous provider #{old_provider&.class&.name || "unknown"}: #{e.message}")
          end
        end

        # Initialize provider outside the mutex to avoid blocking other operations
        if needs_init
          # Spec 2.8.5.1: a provider without init is READY, and its handlers have run, when set_provider returns
          if wait_for_init || !has_init
            init_provider(provider, context_for_init, domain:, attempt:, raise_on_error: wait_for_init)
            # Replaced or shut down while init ran: fail like the waiters on this attempt did
            raise incomplete_init_error(provider, "initialization did not complete") if wait_for_init && attempt.state != :succeeded
          else
            init_thread = Thread.new do
              init_provider(provider, context_for_init, domain:, attempt:, raise_on_error: false)
            end
          end
        elsif !has_init
          # Spec 2.8.5.1: each new binding of a provider without init runs its domain's READY handlers
          dispatch_provider_event(provider, ProviderEvent::PROVIDER_READY, token: attempt) unless old_provider.equal?(provider)
        elsif wait_for_init
          # Already registered: wait for an init still in flight, then report its outcome.
          # From inside that init (e.g. a handler of an event it emits) the wait could never end.
          raise incomplete_init_error(provider, "is still initializing on this thread") if running_on_this_thread?(attempt)

          attempt.done.pop
          raise attempt.error || incomplete_init_error(provider, "initialization did not complete") unless attempt.state == :succeeded

          dispatch_provider_event(provider, ProviderEvent::PROVIDER_READY, token: attempt) if legacy
        end
      ensure
        # Fail an attempt no init took over (e.g. a Timeout hit first), or it would stay running forever
        finish_init_attempt(attempt, :failed) if needs_init && !init_thread
      end

      def init_provider(provider, context, domain:, attempt:, raise_on_error: false)
        emits_lifecycle_events = emits_lifecycle_events?(provider)
        attempt.thread = Thread.current
        call_init(provider, context, domain)

        # Settle the attempt before handlers run, so a handler can register this provider again.
        # An abandoned attempt (provider replaced or shut down meanwhile) reports no READY.
        # Spec 2.8.2/2.8.3: a provider that emits its own lifecycle events gets no synthetic READY or ERROR
        dispatch_provider_event(provider, ProviderEvent::PROVIDER_READY, token: attempt) if finish_init_attempt(attempt, :succeeded) && !emits_lifecycle_events
      rescue => e
        # Spec 1.7.5: PROVIDER_FATAL from init makes the provider FATAL
        error_code = EvaluationError.code_for(e)
        error = ProviderInitializationError.new(
          "Provider #{provider.class.name} initialization failed: #{e.message}",
          provider:,
          error_code: error_code,
          original_error: e
        )
        finish_init_attempt(attempt, :failed, error)

        unless emits_lifecycle_events
          dispatch_provider_event(provider, ProviderEvent::PROVIDER_ERROR,
            {error_code: error_code, message: e.message}, token: attempt)
        end

        raise error if raise_on_error
      ensure
        # Reached unsettled only when init raised something other than a StandardError
        finish_init_attempt(attempt, :failed)
      end

      # Caller holds @provider_mutex: the provider was unbound or the API reset before its init settled
      def abandon_init_attempt(attempt)
        return unless attempt

        attempt.state = :failed if attempt.state == :running
        attempt.done.close
      end

      def incomplete_init_error(provider, reason)
        ProviderInitializationError.new("Provider #{provider.class.name} #{reason}", provider:, error_code: Provider::ErrorCode::GENERAL)
      end

      def finish_init_attempt(attempt, state, error = nil)
        @provider_mutex.synchronize do
          return false unless attempt.state == :running

          attempt.state = state
          attempt.error = error
        end
        attempt.done.close
        true
      end

      # An event for a provider already dispatching on this call stack is queued behind the current one
      def dispatch_provider_event(provider, event_type, details = {}, token: nil)
        # Lifecycle events (the SDK's own, or the provider's from its init thread) record status when sent, so
        # set_provider_and_wait returns with it even from the provider's own handler (1.1.2.4); others record it when delivered (5.3.5)
        token ||= running_init_attempt_on_this_thread(provider)
        return if token && !accept_provider_event(provider, event_type, details, token)

        queues = (Thread.current[@dispatch_key] ||= {}.compare_by_identity)
        if (queue = queues[provider])
          queue << [event_type, details.dup, token]
          return
        end

        queue = queues[provider] = [[event_type, details, token]]
        begin
          deliver_provider_event(provider, *queue.shift)
          until queue.empty?
            begin
              deliver_provider_event(provider, *queue.shift)
            rescue => e
              # Its own emitter already returned, so log rather than fail the event that was dispatching
              @logger&.error("Queued provider event failed: #{e.message}")
            end
          end
        ensure
          queues.delete(provider)
          Thread.current[@dispatch_key] = nil if queues.empty?
        end
      end

      def deliver_provider_event(provider, event_type, details, token)
        return unless accept_provider_event(provider, event_type, details, token, record_status: token.nil?)

        event_details = {provider_name: extract_provider_name(provider)}.merge(details)
        run_handlers_for_provider(provider, event_type, event_details)
      end

      private

      # Under the replacement lock, so a late event can't re-track a replaced or shut-down provider
      def accept_provider_event(provider, event_type, details, token, record_status: true)
        @provider_mutex.synchronize do
          return false unless provider_bound?(provider)
          # An SDK READY/ERROR from an earlier registration of this provider is stale
          return false unless token.nil? || @init_attempts[provider].equal?(token)

          @provider_state_registry.update_state_from_event(provider, event_type, details) if record_status
          true
        end
      end

      def provider_bound?(provider)
        @providers.each_value.any? { |p| p.equal?(provider) }
      end

      def extract_provider_name(provider)
        provider.respond_to?(:metadata) ? provider.metadata.name : provider.class.name
      end

      def domain_scoped?(provider)
        provider.respond_to?(:domain_scoped?) && provider.domain_scoped?
      end

      # Spec 2.8.5.1: without init there's nothing to report, so the marker only counts alongside init
      def emits_lifecycle_events?(provider)
        provider.respond_to?(:init) && provider.respond_to?(:emits_lifecycle_events?) && provider.emits_lifecycle_events?
      end

      def running_init_attempt_on_this_thread(provider)
        attempt = @provider_mutex.synchronize { @init_attempts[provider] }
        attempt if attempt && running_on_this_thread?(attempt)
      end

      def running_on_this_thread?(attempt)
        attempt.state == :running && attempt.thread.equal?(Thread.current)
      end

      def warn_legacy_provider(provider)
        return if @logger.nil? || !@provider_mutex.synchronize { @legacy_warned.add?(provider.class) }
        @logger.warn("Provider #{extract_provider_name(provider)} relies on SDK-emitted lifecycle events, which are deprecated; " \
          "emit PROVIDER_READY/PROVIDER_ERROR from init and define emits_lifecycle_events? returning true (spec Appendix E)")
      end

      def validate_domain_scoped_binding!(provider, domain, scoped)
        return unless scoped && provider_bound?(provider) && !@providers[domain].equal?(provider)

        raise ArgumentError, "Cannot bind domain-scoped provider to more than one domain"
      end

      def call_init(provider, context, domain)
        return unless provider.respond_to?(:init)

        parameters = provider.method(:init).parameters
        takes_domain = init_accepts_domain?(parameters)
        if !takes_domain && domain_scoped?(provider)
          @logger&.warn("Provider #{extract_provider_name(provider)} is domain-scoped but its init doesn't accept domain:")
        end

        args = init_accepts_evaluation_context?(parameters) ? [context] : []
        provider.init(*args, **(takes_domain ? {domain:} : {}))
      end

      # Anonymous `**` (from `...`) and delegators' bare `*` can't be trusted to accept `domain:`
      def init_accepts_domain?(parameters)
        parameters.any? do |kind, name|
          ((kind == :key || kind == :keyreq) && name == :domain) || (kind == :keyrest && name && name != :**)
        end
      end

      def init_accepts_evaluation_context?(parameters)
        parameters.any? { |kind, _| kind == :req || kind == :opt || kind == :rest }
      end

      def run_handlers_for_provider(provider, event_type, event_details)
        # Run global handlers (API-level, no domain filtering)
        @event_dispatcher.trigger_event(event_type, event_details)

        # Run client handlers (domain-scoped) outside the lock, so they can add or remove handlers
        handlers = @client_handlers_mutex.synchronize do
          @client_handlers.flat_map do |client, handlers_by_event|
            # Check if this client should receive events from this provider
            client_provider = provider(domain: client.metadata.domain)
            client_provider&.equal?(provider) ? handlers_by_event[event_type] : []
          end
        end

        handlers.each do |handler|
          handler.call(event_details)
        rescue => e
          @logger&.error("Client event handler failed: #{e.message}")
        end
      end

      def run_immediate_handler(event_type, handler, client)
        status_to_event = {
          ProviderState::READY => ProviderEvent::PROVIDER_READY,
          ProviderState::ERROR => ProviderEvent::PROVIDER_ERROR,
          ProviderState::FATAL => ProviderEvent::PROVIDER_ERROR,
          ProviderState::STALE => ProviderEvent::PROVIDER_STALE
        }

        if client.nil?
          # API-level handler: check each bound provider once, however many domains it's bound to
          @providers.values.uniq(&:object_id).each do |provider|
            next unless provider

            provider_state = @provider_state_registry.get_state(provider)

            if event_type == status_to_event[provider_state]
              event_details = build_event_details(provider)

              begin
                handler.call(event_details)
              rescue => e
                @logger&.error("Immediate API event handler failed: #{e.message}")
              end
            end
          end
        else
          # Client-level handler: check specific provider only
          client_provider = provider(domain: client.metadata.domain)
          return unless client_provider

          provider_state = @provider_state_registry.get_state(client_provider)

          if event_type == status_to_event[provider_state]
            event_details = build_event_details(client_provider)

            begin
              handler.call(event_details)
            rescue => e
              @logger&.error("Immediate client event handler failed: #{e.message}")
            end
          end
        end
      end

      def build_event_details(provider)
        stored_details = @provider_state_registry.get_details(provider)
        {provider_name: extract_provider_name(provider)}.merge(stored_details)
      end
    end
  end
end
