# frozen_string_literal: true

RSpec.describe AiTool do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }

  def create_tool(
    parameters: nil,
    script: nil,
    rag_chunk_tokens: nil,
    rag_chunk_overlap_tokens: nil
  )
    AiTool.create!(
      name: "test",
      description: "test",
      parameters: parameters || [{ name: "query", type: "string", desciption: "perform a search" }],
      script: script || "function invoke(params) { return params; }",
      created_by_id: 1,
      summary: "Test tool summary",
      rag_chunk_tokens: rag_chunk_tokens || 374,
      rag_chunk_overlap_tokens: rag_chunk_overlap_tokens || 10,
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

  it "is limited to MAX http requests" do
    script = <<~JS
      function invoke(params) {
        let i = 0;
        while (i < 21) {
          http.get("https://example.com/");
          i += 1;
        }
        return "will not happen";
      }
      JS

    tool = create_tool(script: script)
    runner = tool.runner({}, llm: nil, bot_user: nil, context: {})

    stub_request(:get, "https://example.com/").to_return(
      status: 200,
      body: "Hello World",
      headers: {
      },
    )

    expect { runner.invoke }.to raise_error(DiscourseAi::AiBot::ToolRunner::TooManyRequestsError)
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

  context "when defining RAG fragments" do
    before do
      SiteSetting.authorized_extensions = "txt"
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
      SiteSetting.ai_embeddings_model = "bge-large-en"

      Jobs.run_immediately!
    end

    def create_upload(content, filename)
      upload = nil
      Tempfile.create(filename) do |file|
        file.write(content)
        file.rewind

        upload = UploadCreator.new(file, filename).create_for(Discourse.system_user.id)
      end
      upload
    end

    def stub_embeddings
      # this is a trick, we get ever increasing embeddings, this gives us in turn
      # 100% consistent search results
      @counter = 0
      stub_request(:post, "http://test.com/api/v1/classify").to_return(
        status: 200,
        body: lambda { |req| ([@counter += 1] * 1024).to_json },
        headers: {
        },
      )
    end

    it "allows search within uploads" do
      stub_embeddings

      upload1 = create_upload(<<~TXT, "test.txt")
        1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
      TXT

      upload2 = create_upload(<<~TXT, "test.txt")
        30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50
      TXT

      tool = create_tool(rag_chunk_tokens: 10, rag_chunk_overlap_tokens: 4, script: <<~JS)
        function invoke(params) {
          let result1 = index.search("testing a search", { limit: 1 });
          let result2 = index.search("testing another search", { limit: 3, filenames: ["test.txt"] });

          return [result1, result2];
        }
      JS

      RagDocumentFragment.link_target_and_uploads(tool, [upload1.id, upload2.id])

      result = tool.runner({}, llm: nil, bot_user: nil, context: {}).invoke

      expected = [
        [{ "fragment" => "7 8 9 10 11 12 13 14 15 16", "metadata" => nil }],
        [
          { "fragment" => "36 37 38 39 40 41 42 43 44 45", "metadata" => nil },
          { "fragment" => "30 31 32 33 34 35 36 37", "metadata" => nil },
          { "fragment" => "23 24 25 26 27 28 29 30", "metadata" => nil },
        ],
      ]

      expect(result).to eq(expected)

      # will force a reindex
      tool.rag_chunk_tokens = 5
      tool.rag_chunk_overlap_tokens = 2
      tool.save!

      # this part of the API is a bit awkward, maybe we should do it
      # automatically
      RagDocumentFragment.update_target_uploads(tool, [upload1.id, upload2.id])
      result = tool.runner({}, llm: nil, bot_user: nil, context: {}).invoke

      expected = [
        [{ "fragment" => "4 5 6", "metadata" => nil }],
        [
          { "fragment" => "16 17 18", "metadata" => nil },
          { "fragment" => "13 14 15", "metadata" => nil },
          { "fragment" => "10 11 12", "metadata" => nil },
        ],
      ]

      expect(result).to eq(expected)
    end
  end
end
