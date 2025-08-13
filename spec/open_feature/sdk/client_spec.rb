# frozen_string_literal: true

require "spec_helper"

# https://openfeature.dev/docs/specification/sections/flag-evaluation#12-client-usage

RSpec.describe OpenFeature::SDK::Client do
  subject(:client) { described_class.new(provider: provider, domain:) }
  let(:provider) { OpenFeature::SDK::Provider::NoOpProvider.new }
  let(:domain) { "testing" }
  let(:name) { "my-openfeature-client" }

  context "Requirement 1.2.1" do
    before do
      client.hooks << client_hook
    end

    let(:client_hook) { "some_hook" }

    it "MUST provide a method to add hooks which accepts one or more API-conformant hooks, and appends them to the collection of any previously added hooks. When new hooks are added, previously added hooks are not removed." do
      expect(client).to respond_to(:hooks)
      expect(client.hooks).to have_attributes(size: 1).and eq([client_hook])
    end
  end

  context "Requirement 1.2.2" do
    it "MUST define a metadata member or accessor, containing an immutable name field or accessor of type string, which corresponds to the name value supplied during client creation." do
      expect(client).to respond_to(:metadata)
      expect(client.metadata.domain).to eq(domain)
    end
  end

  context "Flag evaluation" do
    context "Requirement 1.3.1" do
      context "Provide methods for typed flag evaluation, including boolean, numeric, string, and structure, with parameters flag key (string, required), default value (boolean | number | string | structure, required), evaluation context (optional), and evaluation options (optional), which returns the flag value." do
        let(:flag_key) { "my-awesome-feature-flag-key" }

        context "boolean value" do
          it do
            expect(client).to respond_to(:fetch_boolean_value)
          end

          it do
            expect(client.fetch_boolean_value(flag_key: flag_key, default_value: false)).is_a?(FalseClass)
          end

          it do
            expect(client.fetch_boolean_value(flag_key: flag_key, default_value: true)).is_a?(TrueClass)
          end
        end

        context "string value" do
          it do
            expect(client).to respond_to(:fetch_string_value)
          end

          it do
            expect(client.fetch_string_value(flag_key: flag_key, default_value: "default_value")).is_a?(String)
          end
        end

        context "number value" do
          it do
            expect(client).to respond_to(:fetch_number_value)
          end

          it do
            expect(client.fetch_number_value(flag_key: flag_key, default_value: 4)).is_a?(Integer)
          end

          it do
            expect(client.fetch_number_value(flag_key: flag_key, default_value: 95.5)).is_a?(Float)
          end

          context "Condition 1.3.3 - The implementation language differentiates between floating-point numbers and integers." do
            it do
              expect(client.fetch_integer_value(flag_key: flag_key, default_value: 4)).is_a?(Integer)
            end

            it do
              expect(client.fetch_float_value(flag_key: flag_key, default_value: 95.5)).is_a?(Float)
            end
          end
        end

        context "object value" do
          it do
            expect(client).to respond_to(:fetch_object_value)
          end

          it do
            expect(client.fetch_object_value(flag_key: flag_key,
              default_value: {data: "some-data"})).is_a?(Hash)
          end
        end
      end
    end

    context "Requirement 1.3.3" do
      pending
    end

    context "Requirement 1.3.4" do
      context "Guarantee the returned value of any typed flag evaluation method is of the expected type. If the value returned by the underlying provider implementation does not match the expected type, it's to be considered abnormal execution, and the supplied default value should be returned." do
        let(:provider) do
          OpenFeature::SDK::Provider::InMemoryProvider.new(
            {
              "bool" => "no",
              "str" => 123,
              "num" => true,
              "int" => "one",
              "float" => "1.23",
              "obj" => "{}",
            }
          )
        end

        context "boolean value" do
          let(:flag_key) { "bool"}
          let(:default_value) { false }

          it "returns default as type mismatch" do
            fetched = client.fetch_boolean_details(flag_key:, default_value:)

            expect(fetched.value).to be(default_value)
            expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
            expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
          end
        end

        context "string value" do
          let(:flag_key) { "str" }
          let(:default_value) { "default" }

          it "returns default as type mismatch" do
            fetched = client.fetch_string_details(flag_key:, default_value:)

            expect(fetched.value).to be(default_value)
            expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
            expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
          end
        end

        context "number value" do
          let(:flag_key) { "num" }
          let(:default_value) { 4 }

          it "returns default as type mismatch" do
            fetched = client.fetch_number_details(flag_key:, default_value:)

            expect(fetched.value).to be(default_value)
            expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
            expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
          end
        end

        context "integer value" do
          let(:flag_key) { "int" }
          let(:default_value) { 4 }

          it "returns default as type mismatch" do
            fetched = client.fetch_integer_details(flag_key:, default_value:)

            expect(fetched.value).to be(default_value)
            expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
            expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
          end
        end

        context "float value" do
          let(:flag_key) { "float" }
          let(:default_value) { 1.23 }

          it "returns default as type mismatch" do
            fetched = client.fetch_float_details(flag_key:, default_value:)

            expect(fetched.value).to be(default_value)
            expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
            expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
          end
        end

        context "object value" do
          let(:flag_key) { "obj" }
          let(:default_value) { {} }

          it "returns default as type mismatch" do
            fetched = client.fetch_object_details(flag_key:, default_value:)

            expect(fetched.value).to be(default_value)
            expect(fetched.error_code).to eq(OpenFeature::SDK::Provider::ErrorCode::TYPE_MISMATCH)
            expect(fetched.reason).to eq(OpenFeature::SDK::Provider::Reason::ERROR)
          end
        end
      end
    end

    context "Detailed Feature Evaluation" do
      let(:flag_key) { "my-awesome-feature-flag-key" }

      context "boolean value" do
        context "Requirement 1.4.1" do
          it do
            expect(client).to respond_to(:fetch_boolean_details)
          end

          it do
            expect(client.fetch_boolean_details(flag_key: flag_key, default_value: false)).is_a?(OpenFeature::SDK::Provider::ResolutionDetails)
          end
        end

        context "Requirement 1.4.2" do
          it "The evaluation details structure's value field MUST contain the evaluated flag value" do
            expect(client.fetch_boolean_details(flag_key: flag_key, default_value: true).value).is_a?(TrueClass)
            expect(client.fetch_boolean_details(flag_key: flag_key, default_value: false).value).is_a?(FalseClass)
          end
        end

        context "Requirement 1.4.3" do
          pending
        end

        context "Requirement 1.4.4" do
          it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
            expect(client).to respond_to(:fetch_boolean_details)
          end
        end

        context "Requirement 1.4.5" do
          pending
        end
      end

      context "number value" do
        context "Requirement 1.4.1" do
          it do
            expect(client).to respond_to(:fetch_number_details)
          end

          it do
            expect(client.fetch_number_details(flag_key: flag_key, default_value: 1.2)).is_a?(OpenFeature::SDK::Provider::ResolutionDetails)
            expect(client.fetch_number_details(flag_key: flag_key, default_value: 1)).is_a?(OpenFeature::SDK::Provider::ResolutionDetails)
          end
        end

        context "Requirement 1.4.2" do
          it "The evaluation details structure's value field MUST contain the evaluated flag value" do
            expect(client.fetch_number_details(flag_key: flag_key, default_value: 1.0).value).is_a?(Float)
            expect(client.fetch_number_details(flag_key: flag_key, default_value: 1).value).is_a?(Integer)
          end
        end

        context "Requirement 1.4.3" do
          pending
        end

        context "Requirement 1.4.4" do
          it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
            expect(client).to respond_to(:fetch_number_details)
          end
        end
      end

      context "string value" do
        context "Requirement 1.4.1" do
          it do
            expect(client).to respond_to(:fetch_string_details)
          end

          it do
            expect(client.fetch_string_details(flag_key: flag_key, default_value: "some-string")).is_a?(OpenFeature::SDK::Provider::ResolutionDetails)
          end
        end

        context "Requirement 1.4.2" do
          it "The evaluation details structure's value field MUST contain the evaluated flag value" do
            expect(client.fetch_string_details(flag_key: flag_key, default_value: "some-string").value).is_a?(String)
          end
        end

        context "Requirement 1.4.3" do
          pending
        end

        context "Requirement 1.4.4" do
          it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
            expect(client).to respond_to(:fetch_string_details)
          end
        end
      end

      context "object value" do
        context "Requirement 1.4.1" do
          it do
            expect(client).to respond_to(:fetch_object_details)
          end

          it do
            expect(client.fetch_object_details(flag_key: flag_key,
              default_value: {name: "some-name"})).is_a?(OpenFeature::SDK::Provider::ResolutionDetails)
          end
        end

        context "Requirement 1.4.2" do
          it "The evaluation details structure's value field MUST contain the evaluated flag value" do
            expect(client.fetch_object_details(flag_key: flag_key,
              default_value: {name: "some-name"}).value).is_a?(String)
          end
        end

        context "Requirement 1.4.4" do
          it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
            expect(client).to respond_to(:fetch_object_details)
          end
        end
      end

      context "Requirement 1.4.5" do
        pending
      end

      context "Requirement 1.4.6" do
        pending
      end

      context "Requirement 1.4.7" do
        pending
      end

      context "Requirement 1.4.8" do
        pending
      end

      context "Requirement 1.4.9" do
        pending
      end

      context "Requirement 1.4.10" do
        pending
      end

      context "Requirement 1.4.11" do
        pending
      end

      context "Requirement 1.4.12" do
        pending
      end
    end

    context "Evaluation Options" do
      context "Requirement 1.5.1" do
        pending
      end
    end
  end
end
