# frozen_string_literal: true

module OpenFeature
  module SDK
    module Evaluation
      # A container for arbitrary contextual data that can be used as a basis for dynamic evaluation
      class Context < SimpleDelegator

        def initialize(context = Concurrent::Hash.new({}))
          raise ArgumentError, "context must be a Hash" unless context.is_a?(Hash)

          context = Concurrent::Hash[context] unless context.is_a?(Concurrent::Hash)
          super(context)
        end

        def freeze
          super
          deep_freeze
        end

        def targeting_key
          self[:targeting_key]
        end

        def targeting_key=(value)
          raise ArgumentError, "targeting_key must be a String" unless value.is_a?(String)

          self[:targeting_key] = value
        end

        private

        def deep_freeze
          hashes = values.select { |value| value.is_a?(Hash) }
          while hashes.empty? == false
            hash = hashes.pop
            hash.freeze unless hash.frozen?
            hash.each do |key, value|
              key.freeze unless key.frozen?
              value.freeze unless value.frozen?
              hashes << value if value.is_a?(Hash)
            end
          end
        end
      end
    end
  end
end
