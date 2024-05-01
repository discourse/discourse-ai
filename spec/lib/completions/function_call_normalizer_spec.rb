# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::FunctionCallNormalizer do
  let(:buffer) { +"" }

  let(:normalizer) do
    blk = ->(data, cancel) { buffer << data }
    cancel = -> { @done = true }
    DiscourseAi::Completions::FunctionCallNormalizer.new(blk, cancel)
  end

  def pass_through!(data)
    normalizer << data
    expect(buffer[-data.length..-1]).to eq(data)
  end

  it "is usable in non streaming mode" do
    xml = (<<~XML).strip
      hello
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      </invoke>
    XML

    text, function_calls = DiscourseAi::Completions::FunctionCallNormalizer.normalize(xml)

    expect(text).to eq("hello")

    expected_function_calls = (<<~XML).strip
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      <tool_id>tool_0</tool_id>
      </invoke>
      </function_calls>
    XML

    expect(function_calls).to eq(expected_function_calls)
  end

  it "strips junk from end of function calls" do
    xml = (<<~XML).strip
      hello
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      </invoke>
      junk
    XML

    _text, function_calls = DiscourseAi::Completions::FunctionCallNormalizer.normalize(xml)

    expected_function_calls = (<<~XML).strip
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      <tool_id>tool_0</tool_id>
      </invoke>
      </function_calls>
    XML

    expect(function_calls).to eq(expected_function_calls)
  end

  it "returns nil for function calls if there are none" do
    input = "hello world\n"
    text, function_calls = DiscourseAi::Completions::FunctionCallNormalizer.normalize(input)

    expect(text).to eq(input)
    expect(function_calls).to eq(nil)
  end

  it "passes through data if there are no function calls detected" do
    pass_through!("hello")
    pass_through!("<tool_name>hello</tool_name>")
    pass_through!("<parameters><hello>world</hello></parameters>")
    pass_through!("<function_call>")
  end

  it "properly handles non English tools" do
    normalizer << "hello<function"
    expect(buffer).to eq("hello")

    normalizer << "_calls>\n"

    normalizer << (<<~XML).strip
      <invoke>
      <tool_name>hello</tool_name>
      <parameters>
      <hello>世界</hello>
      </parameters>
      </invoke>
    XML

    expected = (<<~XML).strip
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      <parameters>
      <hello>世界</hello>
      </parameters>
      <tool_id>tool_0</tool_id>
      </invoke>
      </function_calls>
    XML

    function_calls = normalizer.function_calls
    expect(function_calls).to eq(expected)
  end

  it "works correctly even if you only give it 1 letter at a time" do
    xml = (<<~XML).strip
      abc
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      <parameters>
      <hello>world</hello>
      </parameters>
      <tool_id>abc</tool_id>
      </invoke>
      <invoke>
      <tool_name>hello2</tool_name>
      <parameters>
      <hello>world</hello>
      </parameters>
      <tool_id>aba</tool_id>
      </invoke>
      </function_calls>
    XML

    xml.each_char { |char| normalizer << char }

    expect(buffer + normalizer.function_calls).to eq(xml)
  end

  it "supports multiple invokes" do
    xml = (<<~XML).strip
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      <parameters>
      <hello>world</hello>
      </parameters>
      <tool_id>abc</tool_id>
      </invoke>
      <invoke>
      <tool_name>hello2</tool_name>
      <parameters>
      <hello>world</hello>
      </parameters>
      <tool_id>aba</tool_id>
      </invoke>
      </function_calls>
    XML

    normalizer << xml

    expect(normalizer.function_calls).to eq(xml)
  end

  it "can will cancel if it encounteres </function_calls>" do
    normalizer << "<function_calls>"
    expect(normalizer.done).to eq(false)
    normalizer << "</function_calls>"
    expect(normalizer.done).to eq(true)
    expect(@done).to eq(true)

    expect(normalizer.function_calls).to eq("<function_calls></function_calls>")
  end

  it "pauses on function call and starts buffering" do
    normalizer << "hello<function_call"
    expect(buffer).to eq("hello")
    expect(normalizer.done).to eq(false)

    normalizer << ">"
    expect(buffer).to eq("hello<function_call>")
    expect(normalizer.done).to eq(false)
  end
end
