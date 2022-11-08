# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module OpenFeature
  module SDK
    # Metadata structure that defines general metadata relating to a <tt>Provider</tt> or <tt>Client</tt>
    #
    # Within the Metadata structure you have access to the following attribute reader:
    #
    # * <tt>name</tt> - Allows you to specify name of the Metadata structure
    #
    # * <tt>version</tt> - Allows you to specify version of the Metadata structure
    #
    # Usage:
    #
    #   metadata = Metadata.new(name: 'name-for-metadata')
    #   metadata.name # 'name-for-metadata'
    #   metadata_two = Metadata.new(name: 'name-for-metadata')
    #   metadata_two == metadata # true - equality based on values
    class Metadata
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(T.nilable(String)) }
      attr_reader :version

      sig { params(name: String, version: T.nilable(String)).void }
      def initialize(name:, version: nil)
        @name = T.let(name.dup, String)
        @version = T.let(version.dup, T.nilable(String))
      end

      sig { params(other: Metadata).returns(T::Boolean) }
      def ==(other)
        @name == other.name && @version == other.version
      end
    end
  end
end
