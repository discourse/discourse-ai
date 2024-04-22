# frozen_string_literal: true

RSpec.describe AiPersona do
  it "validates context settings" do
    persona =
      AiPersona.new(
        name: "test",
        description: "test",
        system_prompt: "test",
        commands: [],
        allowed_group_ids: [],
      )

    expect(persona.valid?).to eq(true)

    persona.max_context_posts = 0
    expect(persona.valid?).to eq(false)
    expect(persona.errors[:max_context_posts]).to eq(["must be greater than 0"])

    persona.max_context_posts = 1
    expect(persona.valid?).to eq(true)

    persona.max_context_posts = nil
    expect(persona.valid?).to eq(true)
  end

  it "allows creation of user" do
    persona =
      AiPersona.create!(
        name: "test",
        description: "test",
        system_prompt: "test",
        commands: [],
        allowed_group_ids: [],
      )

    user = persona.create_user!
    expect(user.username).to eq("test_bot")
    expect(user.name).to eq("Test")
    expect(user.bot?).to be(true)
    expect(user.id).to be <= AiPersona::FIRST_PERSONA_USER_ID
  end

  it "removes all rag embeddings when rag params change" do
    persona =
      AiPersona.create!(
        name: "test",
        description: "test",
        system_prompt: "test",
        commands: [],
        allowed_group_ids: [],
        rag_chunk_tokens: 10,
        rag_chunk_overlap_tokens: 5,
      )

    id =
      RagDocumentFragment.create!(
        ai_persona: persona,
        fragment: "test",
        fragment_number: 1,
        upload: Fabricate(:upload),
      ).id

    persona.rag_chunk_tokens = 20
    persona.save!

    expect(RagDocumentFragment.exists?(id)).to eq(false)
  end

  it "defines singleton methods on system persona classes" do
    forum_helper = AiPersona.find_by(name: "Forum Helper")
    forum_helper.update!(
      user_id: 1,
      mentionable: true,
      default_llm: "anthropic:claude-2",
      max_context_posts: 3,
    )

    klass = forum_helper.class_instance

    expect(klass.id).to eq(forum_helper.id)
    expect(klass.system).to eq(true)
    # tl 0 by default
    expect(klass.allowed_group_ids).to eq([10])
    expect(klass.user_id).to eq(1)
    expect(klass.mentionable).to eq(true)
    expect(klass.default_llm).to eq("anthropic:claude-2")
    expect(klass.max_context_posts).to eq(3)
  end

  it "defines singleton methods non persona classes" do
    persona =
      AiPersona.create!(
        name: "test",
        description: "test",
        system_prompt: "test",
        commands: [],
        allowed_group_ids: [],
        default_llm: "anthropic:claude-2",
        max_context_posts: 3,
        mentionable: true,
        user_id: 1,
      )

    klass = persona.class_instance

    expect(klass.id).to eq(persona.id)
    expect(klass.system).to eq(false)
    expect(klass.allowed_group_ids).to eq([])
    expect(klass.user_id).to eq(1)
    expect(klass.mentionable).to eq(true)
    expect(klass.default_llm).to eq("anthropic:claude-2")
    expect(klass.max_context_posts).to eq(3)
  end

  it "does not leak caches between sites" do
    AiPersona.create!(
      name: "pun_bot",
      description: "you write puns",
      system_prompt: "you are pun bot",
      commands: ["ImageCommand"],
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )

    AiPersona.all_personas

    expect(AiPersona.persona_cache[:value].length).to be > (0)
    RailsMultisite::ConnectionManagement.stubs(:current_db) { "abc" }
    expect(AiPersona.persona_cache[:value]).to eq(nil)
  end

  it "does not allow role change for system personas" do
    persona = AiPersona.find_by(name: "Forum Helper")
    expect(persona.update(role: "message_responder")).to eq(false)
  end

  describe "#message_responder_for" do
    fab!(:group)
    fab!(:responder) do
      AiPersona.create!(
        name: "responder",
        description: "responser",
        system_prompt: "responder prompt",
        role: "message_responder",
        role_group_ids: [group.id],
      )
    end

    it "properly sets role_whispers on the persona" do
      responder.update!(role_whispers: true)

      expect(responder.class_instance.role_whispers).to eq(true)
    end

    it "returns can respond to group pms with a custom persona" do
      expect(AiPersona.message_responder_for(group_id: group.id)[:id]).to eq(responder.id)

      responder.update!(enabled: false)

      expect(AiPersona.message_responder_for(group_id: group.id)).to eq(nil)

      responder.update!(enabled: true, role: "bot")

      expect(AiPersona.message_responder_for(group_id: group.id)).to eq(nil)
    end
  end
end
