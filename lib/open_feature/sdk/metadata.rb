# frozen_string_literal: true

module OpenFeature
  module SDK
    # Metadata structure that defines general metadata relating to a <tt>Provider</tt> or <tt>Client</tt>
    #
    # Within the Metadata structure, the following attribute readers are available:
    #
    # * <tt>name</tt> - Defines the name of the structure
    #
    # * <tt>version</tt> - Allows you to specify version of the Metadata structure
    #
    # * <tt>domain</tt> - Allows you to specify the domain of the Metadata structure
    #
    # Usage:
    #
    #   metadata = Metadata.new(name: 'name-for-metadata', version: 'v1.1.3', domain: 'test')
    #   metadata.name # 'name-for-metadata'
    #   metadata.version # version
    #   metadata_two = Metadata.new(name: 'name-for-metadata')
    #   metadata_two == metadata # true - equality based on values
    class Metadata
      attr_reader :name, :version, :domain

      def initialize(name:, version: nil, domain: nil)
        @name = name
        @version = version
        @domain = domain
      end

      def ==(other)
        raise ArgumentError("Expected comparison to be between Metadata object") unless other.is_a?(Metadata)

        @name == other.name && @version == other.version
      end
    end
  end
end
