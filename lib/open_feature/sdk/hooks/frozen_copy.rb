# frozen_string_literal: true

module OpenFeature
  module SDK
    module Hooks
      # A deep-frozen copy of a hook input, so hooks can't change it and the caller's object isn't frozen (spec 4.1.3, 4.2.2)
      def self.frozen_copy(value)
        Ractor.make_shareable(value, copy: true)
      rescue
        value.dup.freeze # shortcut: when something inside can't be copied (a Mutex, Queue or Proc), only the top level is frozen
      end
    end
  end
end
