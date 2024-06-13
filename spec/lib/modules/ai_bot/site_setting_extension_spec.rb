#frozen_string_literal: true

describe DiscourseAi::AiBot::SiteSettingsExtension do
  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:gpt_35_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  def user_exists?(model)
    DiscourseAi::AiBot::EntryPoint.find_user_from_model(model).present?
  end

  it "correctly creates/deletes bot accounts as needed" do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = gpt_4.name

    expect(user_exists?("gpt-4")).to eq(true)
    expect(user_exists?("gpt-3.5-turbo")).to eq(false)
    expect(user_exists?("claude-2")).to eq(false)

    SiteSetting.ai_bot_enabled_chat_bots = gpt_35_turbo.name

    expect(user_exists?("gpt-4")).to eq(false)
    expect(user_exists?("gpt-3.5-turbo")).to eq(true)
    expect(user_exists?("claude-2")).to eq(false)

    SiteSetting.ai_bot_enabled_chat_bots = [gpt_35_turbo.name, claude_2.name].join("|")

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
    SiteSetting.ai_bot_enabled_chat_bots = gpt_4.name

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
end
