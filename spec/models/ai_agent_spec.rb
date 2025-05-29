# frozen_string_literal: true

RSpec.describe AiAgent do
  subject(:basic_agent) do
    AiAgent.new(
      name: "test",
      description: "test",
      system_prompt: "test",
      tools: [],
      allowed_group_ids: [],
    )
  end

  fab!(:llm_model)
  fab!(:seeded_llm_model) { Fabricate(:llm_model, id: -1) }

  it "validates context settings" do
    expect(basic_agent.valid?).to eq(true)

    basic_agent.max_context_posts = 0
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:max_context_posts]).to eq(["must be greater than 0"])

    basic_agent.max_context_posts = 1
    expect(basic_agent.valid?).to eq(true)

    basic_agent.max_context_posts = nil
    expect(basic_agent.valid?).to eq(true)
  end

  it "validates tools" do
    Fabricate(:ai_tool, id: 1)
    Fabricate(:ai_tool, id: 2, name: "Archie search", tool_name: "search")

    expect(basic_agent.valid?).to eq(true)

    basic_agent.tools = %w[search image_generation]
    expect(basic_agent.valid?).to eq(true)

    basic_agent.tools = %w[search image_generation search]
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:tools]).to eq(["Can not have duplicate tools"])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
    ]
    expect(basic_agent.valid?).to eq(true)
    expect(basic_agent.errors[:tools]).to eq([])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-1", { test: "test" }, false],
    ]
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:tools]).to eq(["Can not have duplicate tools"])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
      "image_generation",
    ]
    expect(basic_agent.valid?).to eq(true)
    expect(basic_agent.errors[:tools]).to eq([])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
      "Search",
    ]
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:tools]).to eq(["Can not have duplicate tools"])
  end

  it "allows creation of user" do
    user = basic_agent.create_user!
    expect(user.username).to eq("test_bot")
    expect(user.name).to eq("Test")
    expect(user.bot?).to be(true)
    expect(user.id).to be <= AiAgent::FIRST_AGENT_USER_ID
  end

  it "removes all rag embeddings when rag params change" do
    agent =
      AiAgent.create!(
        name: "test",
        description: "test",
        system_prompt: "test",
        tools: [],
        allowed_group_ids: [],
        rag_chunk_tokens: 10,
        rag_chunk_overlap_tokens: 5,
      )

    id =
      RagDocumentFragment.create!(
        target: agent,
        fragment: "test",
        fragment_number: 1,
        upload: Fabricate(:upload),
      ).id

    agent.rag_chunk_tokens = 20
    agent.save!

    expect(RagDocumentFragment.exists?(id)).to eq(false)
  end

  it "defines singleton methods on system agent classes" do
    forum_helper = AiAgent.find_by(name: "Forum Helper")
    forum_helper.update!(
      user_id: 1,
      default_llm_id: llm_model.id,
      max_context_posts: 3,
      allow_topic_mentions: true,
      allow_agentl_messages: true,
      allow_chat_channel_mentions: true,
      allow_chat_direct_messages: true,
    )

    klass = forum_helper.class_instance

    expect(klass.id).to eq(forum_helper.id)
    expect(klass.system).to eq(true)
    # tl 0 by default
    expect(klass.allowed_group_ids).to eq([10])
    expect(klass.user_id).to eq(1)
    expect(klass.default_llm_id).to eq(llm_model.id)
    expect(klass.max_context_posts).to eq(3)
    expect(klass.allow_topic_mentions).to eq(true)
    expect(klass.allow_agentl_messages).to eq(true)
    expect(klass.allow_chat_channel_mentions).to eq(true)
    expect(klass.allow_chat_direct_messages).to eq(true)
  end

  it "defines singleton methods non agent classes" do
    agent =
      AiAgent.create!(
        name: "test",
        description: "test",
        system_prompt: "test",
        tools: [],
        allowed_group_ids: [],
        default_llm_id: llm_model.id,
        max_context_posts: 3,
        allow_topic_mentions: true,
        allow_agentl_messages: true,
        allow_chat_channel_mentions: true,
        allow_chat_direct_messages: true,
        user_id: 1,
      )

    klass = agent.class_instance

    expect(klass.id).to eq(agent.id)
    expect(klass.system).to eq(false)
    expect(klass.allowed_group_ids).to eq([])
    expect(klass.user_id).to eq(1)
    expect(klass.default_llm_id).to eq(llm_model.id)
    expect(klass.max_context_posts).to eq(3)
    expect(klass.allow_topic_mentions).to eq(true)
    expect(klass.allow_agentl_messages).to eq(true)
    expect(klass.allow_chat_channel_mentions).to eq(true)
    expect(klass.allow_chat_direct_messages).to eq(true)
  end

  it "does not allow setting allowing chat without a default_llm" do
    agent =
      AiAgent.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_chat_channel_mentions: true,
      )

    expect(agent.valid?).to eq(false)
    expect(agent.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.agents.default_llm_required"),
    )

    agent =
      AiAgent.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_chat_direct_messages: true,
      )

    expect(agent.valid?).to eq(false)
    expect(agent.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.agents.default_llm_required"),
    )

    agent =
      AiAgent.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_topic_mentions: true,
      )

    expect(agent.valid?).to eq(false)
    expect(agent.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.agents.default_llm_required"),
    )
  end

  it "validates allowed seeded model" do
    basic_agent.default_llm_id = seeded_llm_model.id

    SiteSetting.ai_bot_allowed_seeded_models = ""

    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:default_llm]).to include(
      I18n.t("discourse_ai.llm.configuration.invalid_seeded_model"),
    )

    SiteSetting.ai_bot_allowed_seeded_models = "-1"
    expect(basic_agent.valid?).to eq(true)
  end

  it "does not leak caches between sites" do
    AiAgent.create!(
      name: "pun_bot",
      description: "you write puns",
      system_prompt: "you are pun bot",
      tools: ["ImageCommand"],
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )

    AiAgent.all_agents

    expect(AiAgent.agent_cache[:value].length).to be > (0)
    RailsMultisite::ConnectionManagement.stubs(:current_db) { "abc" }
    expect(AiAgent.agent_cache[:value]).to eq(nil)
  end

  describe "system agent validations" do
    let(:system_agent) do
      AiAgent.create!(
        name: "system_agent",
        description: "system agent",
        system_prompt: "system agent",
        tools: %w[Search Time],
        response_format: [{ key: "summary", type: "string" }],
        examples: [%w[user_msg1 assistant_msg1], %w[user_msg2 assistant_msg2]],
        system: true,
      )
    end

    context "when modifying a system agent" do
      it "allows changing tool options without allowing tool additions/removals" do
        tools = [["Search", { "base_query" => "abc" }], ["Time"]]
        system_agent.update!(tools: tools)

        system_agent.reload
        expect(system_agent.tools).to eq(tools)

        invalid_tools = ["Time"]
        system_agent.update(tools: invalid_tools)
        expect(system_agent.errors[:base]).to include(
          I18n.t("discourse_ai.ai_bot.agents.cannot_edit_system_agent"),
        )
      end

      it "doesn't accept response format changes" do
        new_format = [{ key: "summary2", type: "string" }]

        expect { system_agent.update!(response_format: new_format) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end

      it "doesn't accept additional format changes" do
        new_format = [{ key: "summary", type: "string" }, { key: "summary2", type: "string" }]

        expect { system_agent.update!(response_format: new_format) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end

      it "doesn't accept changes to examples" do
        other_examples = [%w[user_msg1 assistant_msg1]]

        expect { system_agent.update!(examples: other_examples) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end
    end
  end

  describe "validates examples format" do
    it "doesn't accept examples that are not arrays" do
      basic_agent.examples = [1]

      expect(basic_agent.valid?).to eq(false)
      expect(basic_agent.errors[:examples].first).to eq(
        I18n.t("discourse_ai.agents.malformed_examples"),
      )
    end

    it "doesn't accept examples that don't come in pairs" do
      basic_agent.examples = [%w[user_msg1]]

      expect(basic_agent.valid?).to eq(false)
      expect(basic_agent.errors[:examples].first).to eq(
        I18n.t("discourse_ai.agents.malformed_examples"),
      )
    end

    it "works when example is well formatted" do
      basic_agent.examples = [%w[user_msg1 assistant1]]

      expect(basic_agent.valid?).to eq(true)
    end
  end
end
