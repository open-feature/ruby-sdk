RSpec.describe "README example" do
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

  it "works" do
    eval @example_codeblock.string_content,
         binding,
         @readme_md.to_s,
         @example_codeblock.source_position[:start_line] + 1
  end
end
