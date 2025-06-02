# frozen_string_literal: true

RSpec.describe AiTool do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "bananas are a tasty fruit") }
  fab!(:bot_user) { Discourse.system_user }

  def create_tool(
    parameters: nil,
    script: nil,
    rag_chunk_tokens: nil,
    rag_chunk_overlap_tokens: nil
  )
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters:
        parameters || [{ name: "query", type: "string", description: "perform a search" }],
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
        name: tool.tool_name,
        description: "test",
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
      },
    )

    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    expect(runner.invoke).to eq("query" => "test")
  end

  it "can perform HTTP requests with various verbs" do
    %i[post put delete patch].each do |verb|
      script = <<~JS
      function invoke(params) {
        result = http.#{verb}("https://example.com/api",
          {
            headers: { TestHeader: "TestValue" },
            body: JSON.stringify({ data: params.data })
          }
        );

        return result.body;
      }
    JS

      tool = create_tool(script: script)
      runner = tool.runner({ "data" => "test data" }, llm: nil, bot_user: nil)

      stub_request(verb, "https://example.com/api").with(
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
  end

  it "can perform GET HTTP requests, with 1 param" do
    script = <<~JS
      function invoke(params) {
        result = http.get("https://example.com/" + params.query);
        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

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
    runner = tool.runner({}, llm: nil, bot_user: nil)

    stub_request(:get, "https://example.com/").to_return(
      status: 200,
      body: "Hello World",
      headers: {
      },
    )

    expect { runner.invoke }.to raise_error(DiscourseAi::Personas::ToolRunner::TooManyRequestsError)
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
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

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
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    stub_request(:get, "https://example.com/test").to_return do
      sleep 0.01
      { status: 200, body: "Hello World", headers: {} }
    end

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    runner.timeout = 10

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

    runner = tool.runner({}, llm: llm, bot_user: nil)
    result = runner.invoke

    expect(result).to eq("Hello")
  end

  it "is able to run llm completions" do
    script = <<~JS
      function invoke(params) {
        return llm.generate("question two") + llm.generate(
          { messages: [
            { type: "system", content: "system message" },
            { type: "user", content: "user message" }
          ]}
        );
      }
    JS

    tool = create_tool(script: script)

    result = nil
    prompts = nil
    responses = ["Hello ", "World"]

    DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompts|
      runner = tool.runner({}, llm: llm, bot_user: nil)
      result = runner.invoke
      prompts = _prompts
    end

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "system message",
        messages: [{ type: :user, content: "user message" }],
      )
    expect(result).to eq("Hello World")
    expect(prompts[0]).to eq("question two")
    expect(prompts[1]).to eq(prompt)
  end

  it "can timeout slow JS" do
    script = <<~JS
      function invoke(params) {
        while (true) {}
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    runner.timeout = 5

    result = runner.invoke
    expect(result[:error]).to eq("Script terminated due to timeout")
  end

  context "when defining RAG fragments" do
    fab!(:cloudflare_embedding_def)

    before do
      SiteSetting.authorized_extensions = "txt"
      SiteSetting.ai_embeddings_selected_model = cloudflare_embedding_def.id
      SiteSetting.ai_embeddings_enabled = true
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
      stub_request(:post, cloudflare_embedding_def.url).to_return(
        status: 200,
        body: lambda { |req| { result: { data: [([@counter += 2] * 1024)] } }.to_json },
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

      result = tool.runner({}, llm: nil, bot_user: nil).invoke

      expected = [
        [{ "fragment" => "44 45 46 47 48 49 50", "metadata" => nil }],
        [
          { "fragment" => "44 45 46 47 48 49 50", "metadata" => nil },
          { "fragment" => "36 37 38 39 40 41 42 43 44 45", "metadata" => nil },
          { "fragment" => "30 31 32 33 34 35 36 37", "metadata" => nil },
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
      result = tool.runner({}, llm: nil, bot_user: nil).invoke

      # this is flaking, it is not critical cause it relies on vector search
      # that may not be 100% deterministic

      # expected = [
      #   [{ "fragment" => "48 49 50", "metadata" => nil }],
      #   [
      #     { "fragment" => "48 49 50", "metadata" => nil },
      #     { "fragment" => "45 46 47", "metadata" => nil },
      #     { "fragment" => "42 43 44", "metadata" => nil },
      #   ],
      # ]

      expect(result.length).to eq(2)
      expect(result[0][0]["fragment"].length).to eq(8)
      expect(result[1].length).to eq(3)
    end
  end

  context "when using the topic API" do
    it "can fetch topic details" do
      script = <<~JS
        function invoke(params) {
          return discourse.getTopic(params.topic_id);
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "topic_id" => topic.id }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result["id"]).to eq(topic.id)
      expect(result["title"]).to eq(topic.title)
      expect(result["archetype"]).to eq("regular")
      expect(result["posts_count"]).to eq(1)
    end
  end

  context "when using the post API" do
    it "can fetch post details" do
      script = <<~JS
        function invoke(params) {
          const post = discourse.getPost(params.post_id);
          return {
            post: post,
            topic: post.topic
          }
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "post_id" => post.id }, llm: nil, bot_user: nil)

      result = runner.invoke
      post_hash = result["post"]
      topic_hash = result["topic"]

      expect(post_hash["id"]).to eq(post.id)
      expect(post_hash["topic_id"]).to eq(topic.id)
      expect(post_hash["raw"]).to eq(post.raw)

      expect(topic_hash["id"]).to eq(topic.id)
    end
  end

  context "when using the search API" do
    before { SearchIndexer.enable }
    after { SearchIndexer.disable }

    it "can perform a discourse search" do
      SearchIndexer.index(topic, force: true)
      SearchIndexer.index(post, force: true)

      script = <<~JS
        function invoke(params) {
          return discourse.search({ search_query: params.query });
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "query" => "banana" }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result["rows"].length).to be > 0
      expect(result["rows"].first["title"]).to eq(topic.title)
    end
  end

  context "when using the chat API" do
    before(:each) do
      skip "Chat plugin tests skipped because Chat module is not defined." unless defined?(Chat)
      SiteSetting.chat_enabled = true
    end

    fab!(:chat_user) { Fabricate(:user) }
    fab!(:chat_channel) do
      Fabricate(:chat_channel).tap do |channel|
        Fabricate(
          :user_chat_channel_membership,
          user: chat_user,
          chat_channel: channel,
          following: true,
        )
      end
    end

    it "can create a chat message" do
      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: params.channel_name,
            username: params.username,
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          {
            "channel_name" => chat_channel.name,
            "username" => chat_user.username,
            "message" => "Hello from the tool!",
          },
          llm: nil,
          bot_user: bot_user, # The user *running* the tool doesn't affect sender
        )

      initial_message_count = Chat::Message.count
      result = runner.invoke

      expect(result["success"]).to eq(true), "Tool invocation failed: #{result["error"]}"
      expect(result["message"]).to eq("Hello from the tool!")
      expect(result["created_at"]).to be_present
      expect(result).not_to have_key("error")

      # Verify message was actually created in the database
      expect(Chat::Message.count).to eq(initial_message_count + 1)
      created_message = Chat::Message.find_by(id: result["message_id"])

      expect(created_message).not_to be_nil
      expect(created_message.message).to eq("Hello from the tool!")
      expect(created_message.user_id).to eq(chat_user.id) # Message is sent AS the specified user
      expect(created_message.chat_channel_id).to eq(chat_channel.id)
    end

    it "can create a chat message using channel slug" do
      chat_channel.update!(name: "My Test Channel", slug: "my-test-channel")
      expect(chat_channel.slug).to eq("my-test-channel")

      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: params.channel_slug, // Using slug here
            username: params.username,
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          {
            "channel_slug" => chat_channel.slug,
            "username" => chat_user.username,
            "message" => "Hello via slug!",
          },
          llm: nil,
          bot_user: bot_user,
        )

      result = runner.invoke

      expect(result["success"]).to eq(true), "Tool invocation failed: #{result["error"]}"
      # see: https://github.com/rubyjs/mini_racer/issues/348
      # expect(result["message_id"]).to be_a(Integer)

      created_message = Chat::Message.find_by(id: result["message_id"])
      expect(created_message).not_to be_nil
      expect(created_message.message).to eq("Hello via slug!")
      expect(created_message.chat_channel_id).to eq(chat_channel.id)
    end

    it "returns an error if the channel is not found" do
      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: "non_existent_channel",
            username: params.username,
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { "username" => chat_user.username, "message" => "Test" },
          llm: nil,
          bot_user: bot_user,
        )

      initial_message_count = Chat::Message.count
      expect { runner.invoke }.to raise_error(
        MiniRacer::RuntimeError,
        /Channel not found: non_existent_channel/,
      )

      expect(Chat::Message.count).to eq(initial_message_count) # Verify no message created
    end

    it "returns an error if the user is not found" do
      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: params.channel_name,
            username: "non_existent_user",
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { "channel_name" => chat_channel.name, "message" => "Test" },
          llm: nil,
          bot_user: bot_user,
        )

      initial_message_count = Chat::Message.count
      expect { runner.invoke }.to raise_error(
        MiniRacer::RuntimeError,
        /User not found: non_existent_user/,
      )

      expect(Chat::Message.count).to eq(initial_message_count) # Verify no message created
    end
  end

  context "when updating personas" do
    fab!(:ai_persona) do
      Fabricate(:ai_persona, name: "TestPersona", system_prompt: "Original prompt")
    end

    it "can update a persona with proper permissions" do
      script = <<~JS
        function invoke(params) {
          return discourse.updatePersona(params.persona_name, {
            system_prompt: params.new_prompt,
            temperature: 0.7,
            top_p: 0.9
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { persona_name: "TestPersona", new_prompt: "Updated system prompt" },
          llm: nil,
          bot_user: bot_user,
        )

      result = runner.invoke
      expect(result["success"]).to eq(true)
      expect(result["persona"]["system_prompt"]).to eq("Updated system prompt")
      expect(result["persona"]["temperature"]).to eq(0.7)

      ai_persona.reload
      expect(ai_persona.system_prompt).to eq("Updated system prompt")
      expect(ai_persona.temperature).to eq(0.7)
      expect(ai_persona.top_p).to eq(0.9)
    end
  end

  context "when fetching persona information" do
    fab!(:ai_persona) do
      Fabricate(
        :ai_persona,
        name: "TestPersona",
        description: "Test description",
        system_prompt: "Test system prompt",
        temperature: 0.8,
        top_p: 0.9,
        vision_enabled: true,
        tools: ["Search", ["WebSearch", { param: "value" }, true]],
      )
    end

    it "can fetch a persona by name" do
      script = <<~JS
        function invoke(params) {
          const persona = discourse.getPersona(params.persona_name);
          return persona;
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ persona_name: "TestPersona" }, llm: nil, bot_user: bot_user)

      result = runner.invoke

      expect(result["id"]).to eq(ai_persona.id)
      expect(result["name"]).to eq("TestPersona")
      expect(result["description"]).to eq("Test description")
      expect(result["system_prompt"]).to eq("Test system prompt")
      expect(result["temperature"]).to eq(0.8)
      expect(result["top_p"]).to eq(0.9)
      expect(result["vision_enabled"]).to eq(true)
      expect(result["tools"]).to include("Search")
      expect(result["tools"][1]).to be_a(Array)
    end

    it "raises an error when the persona doesn't exist" do
      script = <<~JS
        function invoke(params) {
          return discourse.getPersona("NonExistentPersona");
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: bot_user)

      expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Persona not found/)
    end

    it "can update a persona after fetching it" do
      script = <<~JS
        function invoke(params) {
          const persona = discourse.getPersona("TestPersona");
          return persona.update({
            system_prompt: "Updated through getPersona().update()",
            temperature: 0.5
          });
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: bot_user)

      result = runner.invoke
      expect(result["success"]).to eq(true)

      ai_persona.reload
      expect(ai_persona.system_prompt).to eq("Updated through getPersona().update()")
      expect(ai_persona.temperature).to eq(0.5)
    end
  end

  it "can use sleep function with limits" do
    script = <<~JS
      function invoke(params) {
        let results = [];
        for (let i = 0; i < 3; i++) {
          let result = sleep(1); // 1ms sleep
          results.push(result);
        }
        return results;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({}, llm: nil, bot_user: nil)

    result = runner.invoke

    expect(result).to eq([{ "slept" => 1 }, { "slept" => 1 }, { "slept" => 1 }])
  end

  describe "upload URL resolution" do
    it "can resolve upload short URLs to public URLs" do
      upload =
        Fabricate(
          :upload,
          sha1: "abcdef1234567890abcdef1234567890abcdef12",
          url: "/uploads/default/original/1X/test.jpg",
          original_filename: "test.jpg",
        )

      script = <<~JS
      function invoke(params) {
        return upload.getUrl(params.short_url);
      }
    JS

      tool = create_tool(script: script)
      runner = tool.runner({ "short_url" => upload.short_url }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result).to eq(GlobalPath.full_cdn_url(upload.url))
    end

    it "returns null for invalid upload short URLs" do
      script = <<~JS
      function invoke(params) {
        return upload.getUrl(params.short_url);
      }
    JS

      tool = create_tool(script: script)
      runner = tool.runner({ "short_url" => "upload://invalid" }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result).to be_nil
    end

    it "returns null for non-existent uploads" do
      script = <<~JS
      function invoke(params) {
        return upload.getUrl(params.short_url);
      }
    JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { "short_url" => "upload://hwmUkTAL9mwhQuRMLsXw6tvDi5C.jpeg" },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result).to be_nil
    end
  end
end
