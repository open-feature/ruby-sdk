# frozen_string_literal: true

module OpenFeature
  module SDK
    ClientMetadata = Struct.new(:domain, keyword_init: true) do
      alias_method :name, :domain

      def initialize(domain: nil)
        super(domain: domain&.dup&.freeze)
        freeze
      end
    end
  end
end
