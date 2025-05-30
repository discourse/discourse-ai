# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiAgentsController do
  fab!(:admin)
  fab!(:ai_agent)
  fab!(:embedding_definition)
  fab!(:llm_model)

  before do
    sign_in(admin)
    SiteSetting.ai_embeddings_selected_model = embedding_definition.id
    SiteSetting.ai_embeddings_enabled = true
  end

  describe "GET #index" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-agents.json"
      expect(response).to be_successful

      expect(response.parsed_body["ai_agents"].length).to eq(AiAgent.count)
      expect(response.parsed_body["meta"]["tools"].length).to eq(
        DiscourseAi::Agents::Agent.all_available_tools.length,
      )
    end

    it "sideloads llms" do
      get "/admin/plugins/discourse-ai/ai-agents.json"
      expect(response).to be_successful

      expect(response.parsed_body["meta"]["llms"]).to eq(
        [
          {
            id: llm_model.id,
            name: llm_model.display_name,
            vision_enabled: llm_model.vision_enabled,
          }.stringify_keys,
        ],
      )
    end

    it "returns tool options with each tool" do
      agent1 = Fabricate(:ai_agent, name: "search1", tools: ["SearchCommand"])
      agent2 =
        Fabricate(
          :ai_agent,
          name: "search2",
          tools: [["SearchCommand", { base_query: "test" }, true]],
          allow_topic_mentions: true,
          allow_agentl_messages: true,
          allow_chat_channel_mentions: true,
          allow_chat_direct_messages: true,
          default_llm_id: llm_model.id,
          question_consolidator_llm_id: llm_model.id,
          forced_tool_count: 2,
        )
      agent2.create_user!

      get "/admin/plugins/discourse-ai/ai-agents.json"
      expect(response).to be_successful

      serializer_agent1 = response.parsed_body["ai_agents"].find { |p| p["id"] == agent1.id }
      serializer_agent2 = response.parsed_body["ai_agents"].find { |p| p["id"] == agent2.id }

      expect(serializer_agent2["allow_topic_mentions"]).to eq(true)
      expect(serializer_agent2["allow_agentl_messages"]).to eq(true)
      expect(serializer_agent2["allow_chat_channel_mentions"]).to eq(true)
      expect(serializer_agent2["allow_chat_direct_messages"]).to eq(true)

      expect(serializer_agent2["default_llm_id"]).to eq(llm_model.id)
      expect(serializer_agent2["question_consolidator_llm_id"]).to eq(llm_model.id)
      expect(serializer_agent2["user_id"]).to eq(agent2.user_id)
      expect(serializer_agent2["user"]["id"]).to eq(agent2.user_id)
      expect(serializer_agent2["forced_tool_count"]).to eq(2)

      tools = response.parsed_body["meta"]["tools"]
      search_tool = tools.find { |c| c["id"] == "Search" }

      expect(search_tool["help"]).to eq(I18n.t("discourse_ai.ai_bot.tool_help.search"))

      expect(search_tool["options"]).to eq(
        {
          "base_query" => {
            "type" => "string",
            "name" => I18n.t("discourse_ai.ai_bot.tool_options.search.base_query.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.tool_options.search.base_query.description"),
          },
          "max_results" => {
            "type" => "integer",
            "name" => I18n.t("discourse_ai.ai_bot.tool_options.search.max_results.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.tool_options.search.max_results.description"),
          },
          "search_private" => {
            "type" => "boolean",
            "name" => I18n.t("discourse_ai.ai_bot.tool_options.search.search_private.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.tool_options.search.search_private.description"),
          },
        },
      )

      expect(serializer_agent1["tools"]).to eq(["SearchCommand"])
      expect(serializer_agent2["tools"]).to eq(
        [["SearchCommand", { "base_query" => "test" }, true]],
      )
    end

    context "with translations" do
      before do
        SiteSetting.default_locale = "fr"

        TranslationOverride.upsert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.name",
          "Général",
        )
        TranslationOverride.upsert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.description",
          "Général Description",
        )
      end

      after do
        TranslationOverride.revert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.name",
        )
        TranslationOverride.revert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.description",
        )
      end

      it "returns localized agent names and descriptions" do
        get "/admin/plugins/discourse-ai/ai-agents.json"

        id = DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General]
        agent = response.parsed_body["ai_agents"].find { |p| p["id"] == id }

        expect(agent["name"]).to eq("Général")
        expect(agent["description"]).to eq("Général Description")
      end
    end
  end

  describe "GET #edit" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/edit.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_agent"]["name"]).to eq(ai_agent.name)
    end

    it "includes rag uploads for each agent" do
      upload = Fabricate(:upload)
      RagDocumentFragment.link_target_and_uploads(ai_agent, [upload.id])

      get "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/edit.json"
      expect(response).to be_successful

      serialized_agent = response.parsed_body["ai_agent"]

      expect(serialized_agent.dig("rag_uploads", 0, "id")).to eq(upload.id)
      expect(serialized_agent.dig("rag_uploads", 0, "original_filename")).to eq(
        upload.original_filename,
      )
    end
  end

  describe "POST #create" do
    context "with valid params" do
      let(:valid_attributes) do
        {
          name: "superbot",
          description: "Assists with tasks",
          system_prompt: "you are a helpful bot",
          tools: [["search", { "base_query" => "test" }, true]],
          top_p: 0.1,
          temperature: 0.5,
          allow_topic_mentions: true,
          allow_agentl_messages: true,
          allow_chat_channel_mentions: true,
          allow_chat_direct_messages: true,
          default_llm_id: llm_model.id,
          question_consolidator_llm_id: llm_model.id,
          forced_tool_count: 2,
          response_format: [{ key: "summary", type: "string" }],
          examples: [%w[user_msg1 assistant_msg1], %w[user_msg2 assistant_msg2]],
        }
      end

      it "creates a new AiAgent" do
        expect {
          post "/admin/plugins/discourse-ai/ai-agents.json",
               params: { ai_agent: valid_attributes }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }

          expect(response).to be_successful
          agent_json = response.parsed_body["ai_agent"]

          expect(agent_json["name"]).to eq("superbot")
          expect(agent_json["top_p"]).to eq(0.1)
          expect(agent_json["temperature"]).to eq(0.5)
          expect(agent_json["default_llm_id"]).to eq(llm_model.id)
          expect(agent_json["forced_tool_count"]).to eq(2)
          expect(agent_json["allow_topic_mentions"]).to eq(true)
          expect(agent_json["allow_agentl_messages"]).to eq(true)
          expect(agent_json["allow_chat_channel_mentions"]).to eq(true)
          expect(agent_json["allow_chat_direct_messages"]).to eq(true)
          expect(agent_json["question_consolidator_llm_id"]).to eq(llm_model.id)
          expect(agent_json["response_format"].map { |rf| rf["key"] }).to contain_exactly(
            "summary",
          )
          expect(agent_json["examples"]).to eq(valid_attributes[:examples])

          agent = AiAgent.find(agent_json["id"])

          expect(agent.tools).to eq([["search", { "base_query" => "test" }, true]])
          expect(agent.top_p).to eq(0.1)
          expect(agent.temperature).to eq(0.5)
        }.to change(AiAgent, :count).by(1)
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new ai_agent" do
        post "/admin/plugins/discourse-ai/ai-agents.json", params: { ai_agent: { foo: "" } } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "POST #create_user" do
    it "creates a user for the agent" do
      post "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/create-user.json"
      ai_agent.reload

      expect(response).to be_successful
      expect(response.parsed_body["user"]["id"]).to eq(ai_agent.user_id)
    end
  end

  describe "PUT #update" do
    context "with scoped api key" do
      it "allows updates with a properly scoped API key" do
        api_key = Fabricate(:api_key, user: admin, created_by: admin)

        scope =
          ApiKeyScope.create!(
            resource: "discourse_ai",
            action: "update_agents",
            api_key_id: api_key.id,
            allowed_parameters: {
            },
          )

        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
                name: "UpdatedByAPI",
                description: "Updated via API key",
              },
            },
            headers: {
              "Api-Key" => api_key.key,
              "Api-Username" => admin.username,
            }

        expect(response).to have_http_status(:ok)
        ai_agent.reload
        expect(ai_agent.name).to eq("UpdatedByAPI")
        expect(ai_agent.description).to eq("Updated via API key")

        scope.update!(action: "fake")

        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
                name: "UpdatedByAPI 2",
                description: "Updated via API key",
              },
            },
            headers: {
              "Api-Key" => api_key.key,
              "Api-Username" => admin.username,
            }

        expect(response).not_to have_http_status(:ok)
      end
    end

    it "allows us to trivially clear top_p and temperature" do
      agent = Fabricate(:ai_agent, name: "test_bot2", top_p: 0.5, temperature: 0.1)
      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              top_p: "",
              temperature: "",
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload

      expect(agent.top_p).to eq(nil)
      expect(agent.temperature).to eq(nil)
    end

    it "supports updating rag params" do
      agent = Fabricate(:ai_agent, name: "test_bot2")

      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              rag_chunk_tokens: "102",
              rag_chunk_overlap_tokens: "12",
              rag_conversation_chunks: "13",
              rag_llm_model_id: llm_model.id,
              question_consolidator_llm_id: llm_model.id,
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload

      expect(agent.rag_chunk_tokens).to eq(102)
      expect(agent.rag_chunk_overlap_tokens).to eq(12)
      expect(agent.rag_conversation_chunks).to eq(13)
      expect(agent.rag_llm_model_id).to eq(llm_model.id)
      expect(agent.question_consolidator_llm_id).to eq(llm_model.id)
    end

    it "supports updating vision params" do
      agent = Fabricate(:ai_agent, name: "test_bot2")
      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              vision_enabled: true,
              vision_max_pixels: 512 * 512,
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload

      expect(agent.vision_enabled).to eq(true)
      expect(agent.vision_max_pixels).to eq(512 * 512)
    end

    it "does not allow temperature and top p changes on stock agents" do
      put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
          params: {
            ai_agent: {
              top_p: 0.5,
              temperature: 0.1,
            },
          }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "with valid params" do
      it "updates the requested ai_agent" do
        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
                name: "SuperBot",
                enabled: false,
                tools: ["search"],
              },
            }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")

        ai_agent.reload
        expect(ai_agent.name).to eq("SuperBot")
        expect(ai_agent.enabled).to eq(false)
        expect(ai_agent.tools).to eq([["search", nil, false]])
      end
    end

    context "with system agents" do
      it "does not allow editing of system prompts" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                system_prompt: "you are not a helpful bot",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of tools" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                tools: %w[SearchCommand ImageCommand],
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of name and description cause it is localized" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                name: "bob",
                description: "the bob",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does allow some actions" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_1]],
                enabled: false,
                priority: 989,
              },
            }

        expect(response).to be_successful
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the ai_agent" do
        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
                name: "",
              },
            } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested ai_agent" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(AiAgent, :count).by(-1)
    end

    it "is not allowed to delete system agents" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json"
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        # let's make sure this is translated
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      }.not_to change(AiAgent, :count)
    end
  end

  describe "#stream_reply" do
    fab!(:llm) { Fabricate(:llm_model, name: "fake_llm", provider: "fake") }
    let(:fake_endpoint) { DiscourseAi::Completions::Endpoints::Fake }

    before { fake_endpoint.delays = [] }

    after { fake_endpoint.reset! }

    it "ensures agent exists" do
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json"
      expect(response).to have_http_status(:unprocessable_entity)
      # this ensures localization key is actually in the yaml
      expect(response.body).to include("agent_name")
    end

    it "ensures question exists" do
      ai_agent.update!(default_llm_id: llm.id)

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             user_unique_id: "site:test.com:user_id:1",
           }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("query")
    end

    it "ensure agent has a user specified" do
      ai_agent.update!(default_llm_id: llm.id)

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             query: "how are you today?",
             user_unique_id: "site:test.com:user_id:1",
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("associated")
    end

    def validate_streamed_response(raw_http, expected)
      lines = raw_http.split("\r\n")

      header_lines, _, payload_lines = lines.chunk { |l| l == "" }.map(&:last)

      preamble = (<<~PREAMBLE).strip
        HTTP/1.1 200 OK
        Content-Type: text/plain; charset=utf-8
        Transfer-Encoding: chunked
        Cache-Control: no-cache, no-store, must-revalidate
        Connection: close
        X-Accel-Buffering: no
        X-Content-Type-Options: nosniff
      PREAMBLE

      expect(header_lines.join("\n")).to eq(preamble)

      parsed = +""

      context_info = nil

      payload_lines.each_slice(2) do |size, data|
        size = size.to_i(16)
        data = data.to_s
        expect(data.bytesize).to eq(size)

        if size > 0
          json = JSON.parse(data)
          parsed << json["partial"].to_s

          context_info = json if json["topic_id"]
        end
      end

      expect(parsed).to eq(expected)

      context_info
    end

    it "is able to create a new conversation" do
      Jobs.run_immediately!
      # trust level 0
      SiteSetting.ai_bot_allowed_groups = "10"

      fake_endpoint.fake_content = ["This is a test! Testing!", "An amazing title"]

      ai_agent.create_user!
      ai_agent.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_agentl_messages: true,
        system_prompt: "you are a helpful bot",
      )

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_name: ai_agent.name,
             query: "how are you today?",
             user_unique_id: "site:test.com:user_id:1",
             preferred_username: "test_user",
             custom_instructions: "To be appended to system prompt",
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      # this is a fake response but it catches errors
      expect(response).to have_http_status(:no_content)

      raw = io_out.read
      context_info = validate_streamed_response(raw, "This is a test! Testing!")

      system_prompt = fake_endpoint.previous_calls[-2][:dialect].prompt.messages.first[:content]

      expect(system_prompt).to eq("you are a helpful bot\nTo be appended to system prompt")

      expect(context_info["topic_id"]).to be_present
      topic = Topic.find(context_info["topic_id"])
      last_post = topic.posts.order(:created_at).last
      expect(last_post.raw).to eq("This is a test! Testing!")

      user_post = topic.posts.find_by(post_number: 1)
      expect(user_post.raw).to eq("how are you today?")

      # need ai agent and user
      expect(topic.topic_allowed_users.count).to eq(2)
      expect(topic.archetype).to eq(Archetype.private_message)
      expect(topic.title).to eq("An amazing title")
      expect(topic.posts.count).to eq(2)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(name: "categories", parameters: {}, id: "tool_1")

      fake_endpoint.fake_content = [tool_call, "this is the response after the tool"]
      # this simplifies function calls
      fake_endpoint.chunk_count = 1

      ai_agent.update!(tools: ["Categories"])

      # lets also unstage the user and add the user to tl0
      # this will ensure there are no feedback loops
      new_user = user_post.user
      new_user.update!(staged: false)
      Group.user_trust_level_change!(new_user.id, new_user.trust_level)

      # double check this happened and user is in group
      agents = AiAgent.allowed_modalities(user: new_user.reload, allow_agentl_messages: true)
      expect(agents.count).to eq(1)

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             query: "how are you now?",
             user_unique_id: "site:test.com:user_id:1",
             preferred_username: "test_user",
             topic_id: context_info["topic_id"],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      # this is a fake response but it catches errors
      expect(response).to have_http_status(:no_content)

      raw = io_out.read
      context_info = validate_streamed_response(raw, "this is the response after the tool")

      topic = topic.reload
      last_post = topic.posts.order(:created_at).last

      expect(last_post.raw).to end_with("this is the response after the tool")
      # function call is visible in the post
      expect(last_post.raw[0..8]).to eq("<details>")

      user_post = topic.posts.find_by(post_number: 3)
      expect(user_post.raw).to eq("how are you now?")
      expect(user_post.user.username).to eq("test_user")
      expect(user_post.user.custom_fields).to eq(
        { "ai-stream-conversation-unique-id" => "site:test.com:user_id:1" },
      )

      expect(topic.posts.count).to eq(4)
    end
  end
end
