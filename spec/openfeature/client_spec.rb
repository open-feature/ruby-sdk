# frozen_string_literal: true

require "./src/open_feature"
require "./src/no_op_provider"
require "./src/provider"
require "./src/hook/hook"
require "./src/metadata"
require "./src/client"

require "spec_helper"

describe OpenFeature::Client do
  before do
    subject
  end

  context "Requirement 1.2.1" do
    subject do
      OpenFeature.configure do |config|
        config.provider = NoOpProvider.new
        config.hooks << api_hook1
        config.hooks << api_hook2
      end

      client = OpenFeature.build_client(name: "my-openfeature-client")
      client.hooks << client_hook1
      client
    end

    let(:api_hook1) do
      Class.new do
        include Hook
      end
    end
    let(:api_hook2) do
      Class.new do
        include Hook
      end
    end
    let(:client_hook1) do
      Class.new do
        include Hook
      end
    end

    it "MUST provide a method to add hooks which accepts one or more API-conformant hooks, and appends them to the collection of any previously added hooks. When new hooks are added, previously added hooks are not removed." do
      expect(subject).to respond_to(:hooks)
      expect(subject.hooks).to have_attributes(size: 1).and eq([client_hook1])
    end
  end

  context "Requirement 1.2.2" do
    subject do
      OpenFeature.configure do |config|
        config.provider = NoOpProvider.new
      end

      OpenFeature.build_client(name: "my-openfeature-client")
    end

    it "MUST define a metadata member or accessor, containing an immutable name field or accessor of type string, which corresponds to the name value supplied during client creation." do
      expect(subject).to respond_to(:metadata)
      expect(subject.metadata).to respond_to(:name)
      expect(subject.metadata.name).to eq("my-openfeature-client")
    end
  end

  context "Flag evaluation" do
    context "Requirement 1.3.1" do
      context "Provide methods for typed flag evaluation, including boolean, numeric, string, and structure, with parameters flag key (string, required), default value (boolean | number | string | structure, required), evaluation context (optional), and evaluation options (optional), which returns the flag value." do
        subject(:client) do
          OpenFeature.build_client(name: "client")
        end
        let(:flag_key) { "my-awesome-feature-flag-key" }

        context "boolean value" do
          it do
            expect(client).to respond_to(:fetch_boolean_value).with(4).arguments
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
            expect(client).to respond_to(:fetch_string_value).with(4).arguments
          end

          it do
            expect(client.fetch_string_value(flag_key: flag_key, default_value: "default_value")).is_a?(String)
          end
        end

        context "number value" do
          it do
            expect(client).to respond_to(:fetch_number_value).with(4).arguments
          end

          context "Condition 1.3.2 - The implementation language differentiates between floating-point numbers and integers." do
            it do
              expect(client.fetch_number_value(flag_key: flag_key, default_value: 4)).is_a?(Integer)
            end

            it do
              expect(client.fetch_number_value(flag_key: flag_key, default_value: 95.5)).is_a?(Float)
            end
          end
        end

        context "object value" do
          it do
            expect(client).to respond_to(:fetch_object_value).with(4).arguments
          end

          it do
            expect(client.fetch_object_value(flag_key: flag_key,
                                             default_value: JSON.dump({ data: "some-data" }))).is_a?(String)
          end
        end
      end
    end

    context "Requirement 1.4.1" do
      context "MUST provide methods for detailed flag value evaluation with parameters flag key (string, required), default value (boolean | number | string | structure, required), evaluation context (optional), and evaluation options (optional), which returns an evaluation details structure." do
        subject(:client) do
          OpenFeature.build_client(name: "client")
        end
        let(:flag_key) { "my-awesome-feature-flag-key" }

        context "boolean value" do
          it do
            expect(client).to respond_to(:fetch_boolean_details).with(4).arguments
          end

          it do
            expect(client.fetch_boolean_details(flag_key: flag_key, default_value: false)).is_a?(ResolutionDetails)
          end

          context "Requirement 1.4.2" do
            it "The evaluation details structure's value field MUST contain the evaluated flag value" do
              expect(client.fetch_boolean_details(flag_key: flag_key, default_value: true).value).is_a?(TrueClass)
              expect(client.fetch_boolean_details(flag_key: flag_key, default_value: false).value).is_a?(FalseClass)
            end
          end

          context "Requirement 1.4.4" do
            it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
              expect(client).to respond_to(:fetch_boolean_details).with(4).arguments.and_keywords(:flag_key,
                                                                                                  :default_value, :evaluation_context, :evaluation_options)
            end
          end
        end

        context "number value" do
          it do
            expect(client).to respond_to(:fetch_number_details).with(4).arguments.and_keywords(:flag_key,
                                                                                               :default_value, :evaluation_context, :evaluation_options)
          end

          it do
            expect(client.fetch_number_details(flag_key: flag_key, default_value: 1.2)).is_a?(ResolutionDetails)
            expect(client.fetch_number_details(flag_key: flag_key, default_value: 1)).is_a?(ResolutionDetails)
          end

          context "Requirement 1.4.2" do
            it "The evaluation details structure's value field MUST contain the evaluated flag value" do
              expect(client.fetch_number_details(flag_key: flag_key, default_value: 1.0).value).is_a?(Float)
              expect(client.fetch_number_details(flag_key: flag_key, default_value: 1).value).is_a?(Integer)
            end
          end

          context "Requirement 1.4.4" do
            it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
              expect(client).to respond_to(:fetch_number_details).with(4).arguments.and_keywords(:flag_key,
                                                                                                 :default_value, :evaluation_context, :evaluation_options)
            end
          end
        end

        context "string value" do
          it do
            expect(client).to respond_to(:fetch_string_details).with(4).arguments.and_keywords(:flag_key,
                                                                                               :default_value, :evaluation_context, :evaluation_options)
          end

          it do
            expect(client.fetch_string_details(flag_key: flag_key, default_value: "some-string")).is_a?(ResolutionDetails)
          end

          context "Requirement 1.4.2" do
            it "The evaluation details structure's value field MUST contain the evaluated flag value" do
              expect(client.fetch_string_details(flag_key: flag_key, default_value: "some-string").value).is_a?(String)
            end
          end

          context "Requirement 1.4.4" do
            it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
              expect(client).to respond_to(:fetch_string_details).with(4).arguments.and_keywords(:flag_key,
                                                                                                 :default_value, :evaluation_context, :evaluation_options)
            end
          end
        end

        context "object value" do
          it do
            expect(client).to respond_to(:fetch_object_details).with(4).arguments.and_keywords(:flag_key,
                                                                                               :default_value, :evaluation_context, :evaluation_options)
          end

          it do
            expect(client.fetch_object_details(flag_key: flag_key,
                                               default_value: JSON.dump({ name: "some-name" }))).is_a?(ResolutionDetails)
          end

          context "Requirement 1.4.2" do
            it "The evaluation details structure's value field MUST contain the evaluated flag value" do
              expect(client.fetch_object_details(flag_key: flag_key,
                                                 default_value: JSON.dump({ name: "some-name" })).value).is_a?(String)
            end
          end

          context "Requirement 1.4.4" do
            it "The evaluation details structure's flag key field MUST contain the flag key argument passed to the detailed flag evaluation method." do
              expect(client).to respond_to(:fetch_object_details).with(4).arguments.and_keywords(:flag_key,
                                                                                                 :default_value, :evaluation_context, :evaluation_options)
            end
          end
        end
      end
    end
  end
end
