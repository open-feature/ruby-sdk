# frozen_string_literal: true

require 'spec_helper'

require_relative "../../../lib/openfeature/sdk/provider/no_op_provider"


describe OpenFeature::SDK::Provider::NoOpProvider do
  subject(:provider) { described_class.new }
  let(:flag_key) { 'some-feature-flag-key' }

  context 'Requirement 2.1.1' do
    it 'MUST define a metadata member or accessor, containing a name field or accessor of type string, which identifies the provider implementation.' do
      expect(provider).to respond_to(:metadata)
      expect(provider.metadata).to respond_to(:name)
      expect(provider.metadata.name).to eq(described_class::NAME)
    end
  end

  context 'Requirement 2.2.1' do
    context 'MUST define methods to resolve flag values, with parameters flag key (string, required), default value (boolean | number | string | structure, required) and evaluation context (optional), which returns a flag resolution structure.' do
      context 'boolean value' do
        it do
          expect(provider).to respond_to(:fetch_boolean_value).with(3).arguments.and_keywords(:flag_key,
                                                                                              :default_value, :evaluation_context)
        end

        it do
          expect(provider.fetch_boolean_value(flag_key:, default_value: false)).is_a?(ResolutionDetails)
        end
      end

      context 'number value' do
        it do
          expect(provider).to respond_to(:fetch_number_value).with(3).arguments.and_keywords(:flag_key,
                                                                                             :default_value, :evaluation_context)
        end

        it do
          expect(provider.fetch_number_value(flag_key:, default_value: 1.0)).is_a?(ResolutionDetails)
          expect(provider.fetch_number_value(flag_key:, default_value: 1)).is_a?(ResolutionDetails)
        end
      end

      context 'string value' do
        it do
          expect(provider).to respond_to(:fetch_string_value).with(3).arguments.and_keywords(:flag_key,
                                                                                             :default_value, :evaluation_context)
        end

        it do
          expect(provider.fetch_string_value(flag_key:, default_value: 'some-string-value')).is_a?(ResolutionDetails)
        end
      end

      context 'boolean value' do
        it do
          expect(provider).to respond_to(:fetch_object_value).with(3).arguments.and_keywords(:flag_key,
                                                                                             :default_value, :evaluation_context)
        end

        it do
          expect(provider.fetch_object_value(flag_key:,
                                             default_value: JSON.dump({ example: 'some-cool-object-value' }))).is_a?(ResolutionDetails)
        end
      end
    end
  end

  context 'Requirement 2.2.3' do
    context "SHOULD populate the flag resolution structure's variant field with a string identifier corresponding to the returned flag value" do
      context 'boolean value' do
        it do
          expect(provider.fetch_boolean_value(flag_key:, default_value: false).value).is_a?(FalseClass)
          expect(provider.fetch_boolean_value(flag_key:, default_value: false).value).is_a?(TrueClass)
        end
      end

      context 'number value' do
        it do
          expect(provider.fetch_number_value(flag_key:, default_value: 1.0).value).is_a?(Float)
          expect(provider.fetch_number_value(flag_key:, default_value: 1).value).is_a?(Integer)
        end
      end

      context 'string value' do
        it do
          expect(provider.fetch_string_value(flag_key:, default_value: 'some-string-value').value).is_a?(String)
        end
      end

      context 'boolean value' do
        it do
          expect(provider.fetch_object_value(flag_key:,
                                             default_value: JSON.dump({ example: 'some-cool-object-value' }))).is_a?(String)
        end
      end
    end
  end

  context 'Requirement 2.2.4' do
    context "MUST populate the flag resolution structure's value field with the resolved flag value." do
      context 'boolean value' do
        it do
          expect(provider.fetch_boolean_value(flag_key:, default_value: false).value).is_a?(FalseClass)
          expect(provider.fetch_boolean_value(flag_key:, default_value: false).value).is_a?(TrueClass)
        end
      end

      context 'number value' do
        it do
          expect(provider.fetch_number_value(flag_key:, default_value: 1.0).value).is_a?(Float)
          expect(provider.fetch_number_value(flag_key:, default_value: 1).value).is_a?(Integer)
        end
      end

      context 'string value' do
        it do
          expect(provider.fetch_string_value(flag_key:, default_value: 'some-string-value').value).is_a?(String)
        end
      end

      context 'boolean value' do
        it do
          expect(provider.fetch_object_value(flag_key:,
                                             default_value: JSON.dump({ example: 'some-cool-object-value' }))).is_a?(String)
        end
      end
    end
  end
end
