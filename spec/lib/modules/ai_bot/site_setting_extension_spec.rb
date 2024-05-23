#frozen_string_literal: true

describe DiscourseAi::AiBot::SiteSettingsExtension do
  def user_exists?(model)
    DiscourseAi::AiBot::EntryPoint.find_user_from_model(model).present?
  end

  it "correctly creates/deletes bot accounts as needed" do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"

    expect(user_exists?("gpt-4")).to eq(true)
    expect(user_exists?("gpt-3.5-turbo")).to eq(false)
    expect(user_exists?("claude-2")).to eq(false)

    SiteSetting.ai_bot_enabled_chat_bots = "gpt-3.5-turbo"

    expect(user_exists?("gpt-4")).to eq(false)
    expect(user_exists?("gpt-3.5-turbo")).to eq(true)
    expect(user_exists?("claude-2")).to eq(false)

    SiteSetting.ai_bot_enabled_chat_bots = "gpt-3.5-turbo|claude-2"

    expect(user_exists?("gpt-4")).to eq(false)
    expect(user_exists?("gpt-3.5-turbo")).to eq(true)
    expect(user_exists?("claude-2")).to eq(true)

    SiteSetting.ai_bot_enabled = false

    expect(user_exists?("gpt-4")).to eq(false)
    expect(user_exists?("gpt-3.5-turbo")).to eq(false)
    expect(user_exists?("claude-2")).to eq(false)
  end

  it "leaves accounts around if they have any posts" do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"

    user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-4")

    create_post(user: user, raw: "this is a test post")

    user.reload
    SiteSetting.ai_bot_enabled = false

    user.reload
    expect(user.active).to eq(false)

    SiteSetting.ai_bot_enabled = true

    user.reload
    expect(user.active).to eq(true)
  end

  it "creates bot users for custom LLM models" do
    custom_llm = Fabricate(:llm_model, provider: "ollama", name: "llama3")

    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = custom_llm.name

    expect(User.exists?(name: custom_llm.name.titleize)).to eq(true)
  end
end
