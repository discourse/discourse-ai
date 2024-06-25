# frozen_string_literal: true

RSpec.describe AiTool do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy_from_obj(llm_model) }

  def create_tool(parameters: nil, script: nil)
    AiTool.create!(
      name: "test",
      description: "test",
      parameters: parameters || [{ name: "query", type: "string", desciption: "perform a search" }],
      script: script || "function invoke(params) { return params; }",
      created_by_id: 1,
      summary: "Test tool summary",
    )
  end

  it "it can run a basic tool" do
    tool = create_tool

    expect(tool.signature).to eq(
      {
        name: "test",
        description: "test",
        parameters: [{ name: "query", type: "string", desciption: "perform a search" }],
      },
    )

    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil, context: {})

    expect(runner.invoke).to eq("query" => "test")
  end

  it "can perform POST HTTP requests" do
    script = <<~JS
    function invoke(params) {
      result = http.post("https://example.com/api",
        {
          headers: { TestHeader: "TestValue" },
          body: JSON.stringify({ data: params.data })
        }
      );

      return result.body;
    }
  JS

    tool = create_tool(script: script)
    runner = tool.runner({ "data" => "test data" }, llm: nil, bot_user: nil, context: {})

    stub_request(:post, "https://example.com/api").with(
      body: "{\"data\":\"test data\"}",
      headers: {
        "Accept" => "*/*",
        "Testheader" => "TestValue",
        "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
      },
    ).to_return(status: 200, body: "Success", headers: {})

    result = runner.invoke

    expect(result).to eq("Success")
  end

  it "can perform GET HTTP requests, with 1 param" do
    script = <<~JS
      function invoke(params) {
        result = http.get("https://example.com/" + params.query);
        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil, context: {})

    stub_request(:get, "https://example.com/test").with(
      headers: {
        "Accept" => "*/*",
        "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
      },
    ).to_return(status: 200, body: "Hello World", headers: {})

    result = runner.invoke

    expect(result).to eq("Hello World")
  end

  it "can perform GET HTTP requests" do
    script = <<~JS
      function invoke(params) {
        result = http.get("https://example.com/" + params.query,
          { headers: { TestHeader: "TestValue" } }
        );

        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil, context: {})

    stub_request(:get, "https://example.com/test").with(
      headers: {
        "Accept" => "*/*",
        "Testheader" => "TestValue",
        "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
      },
    ).to_return(status: 200, body: "Hello World", headers: {})

    result = runner.invoke

    expect(result).to eq("Hello World")
  end

  it "will not timeout on slow HTTP reqs" do
    script = <<~JS
      function invoke(params) {
        result = http.get("https://example.com/" + params.query,
          { headers: { TestHeader: "TestValue" } }
        );

        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil, context: {})

    stub_request(:get, "https://example.com/test").to_return do
      sleep 0.01
      { status: 200, body: "Hello World", headers: {} }
    end

    runner.timeout = 5

    result = runner.invoke

    expect(result).to eq("Hello World")
  end

  it "has access to llm truncation tools" do
    script = <<~JS
      function invoke(params) {
        return llm.truncate("Hello World", 1);
      }
    JS

    tool = create_tool(script: script)

    runner = tool.runner({}, llm: llm, bot_user: nil, context: {})
    result = runner.invoke

    expect(result).to eq("Hello")
  end

  it "can timeout slow JS" do
    script = <<~JS
      function invoke(params) {
        while (true) {}
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil, context: {})

    runner.timeout = 5

    result = runner.invoke
    expect(result[:error]).to eq("Script terminated due to timeout")
  end
end
