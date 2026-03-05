# frozen_string_literal: true

module RecordingHookHelper
  def recording_hook(name, call_log)
    Class.new do
      include OpenFeature::SDK::Hooks::Hook
      define_method(:hook_name) { name }

      define_method(:before) do |hook_context:, hints:|
        call_log << "#{name}:before"
        nil
      end

      define_method(:after) do |hook_context:, evaluation_details:, hints:|
        call_log << "#{name}:after"
      end

      define_method(:error) do |hook_context:, exception:, hints:|
        call_log << "#{name}:error"
      end

      define_method(:finally) do |hook_context:, evaluation_details:, hints:|
        call_log << "#{name}:finally"
      end
    end.new
  end
end

RSpec.configure do |config|
  config.include RecordingHookHelper
end
