# frozen_string_literal: true

# rubocop:disable RSpec/InstanceVariable, RSpec/ExampleLength
RSpec.describe "README example" do # rubocop:disable RSpec/DescribeClass
  before do
    @readme_md = Pathname.new("../../../README.md").expand_path(__FILE__)

    doc = Markly.parse(@readme_md.read)
    doc.walk do |node|
      if node.type == :code_block && node.fence_info == "ruby"
        @example_codeblock = node
        break
      end
    end
  end

  it "exercises code in the README" do
    expect do
      eval @example_codeblock.string_content, # rubocop:disable Security/Eval
           binding,
           @readme_md.to_s,
           @example_codeblock.source_position[:start_line] + 1
    end.not_to raise_error
  end
end
# rubocop:enable RSpec/InstanceVariable, RSpec/ExampleLength
