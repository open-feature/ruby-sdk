# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpenFeature::SDK::ProviderInitializationError do
  let(:provider) { OpenFeature::SDK::Provider::InMemoryProvider.new }
  let(:original_error) { StandardError.new('Original error message') }
  let(:message) { 'Provider initialization failed' }

  describe '#initialize' do
    context 'with all parameters' do
      subject(:error) do
        described_class.new(message, provider:, original_error:)
      end

      it 'sets the message' do
        expect(error.message).to eq(message)
      end

      it 'sets the provider' do
        expect(error.provider).to be(provider)
      end

      it 'sets the original error' do
        expect(error.original_error).to be(original_error)
      end

      it 'inherits from StandardError' do
        expect(error).to be_a(StandardError)
      end
    end

    context 'with minimal parameters' do
      subject(:error) { described_class.new(message) }

      it 'sets the message' do
        expect(error.message).to eq(message)
      end

      it 'has nil provider' do
        expect(error.provider).to be_nil
      end

      it 'has nil original_error' do
        expect(error.original_error).to be_nil
      end
    end

    context 'with provider but no original_error' do
      subject(:error) { described_class.new(message, provider:) }

      it 'sets the provider' do
        expect(error.provider).to be(provider)
      end

      it 'has nil original_error' do
        expect(error.original_error).to be_nil
      end
    end

    context 'with original_error but no provider' do
      subject(:error) { described_class.new(message, original_error:) }

      it 'has nil provider' do
        expect(error.provider).to be_nil
      end

      it 'sets the original_error' do
        expect(error.original_error).to be(original_error)
      end
    end
  end

  describe 'inheritance' do
    it 'can be caught as StandardError' do
      error = described_class.new('Test error')

      expect { raise error }.to raise_error(StandardError)
    end

    it 'can be caught specifically as ProviderInitializationError' do
      error = described_class.new('Test error')

      expect { raise error }.to raise_error(OpenFeature::SDK::ProviderInitializationError)
    end
  end

  describe 'usage in rescue blocks' do
    it 'provides access to provider and original error in rescue block' do
      caught_error = nil

      begin
        raise described_class.new(message, provider:, original_error:)
      rescue OpenFeature::SDK::ProviderInitializationError => e
        caught_error = e
      end

      expect(caught_error).not_to be_nil
      expect(caught_error.provider).to be(provider)
      expect(caught_error.original_error).to be(original_error)
      expect(caught_error.message).to eq(message)
    end
  end
end
