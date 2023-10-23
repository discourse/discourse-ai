#frozen_string_literal: true

describe DiscourseAi::AiBot::SiteSettingsExtension do
  it "correctly creates/deletes bot accounts as needed" do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"

    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT4_ID)).to eq(true)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID)).to eq(false)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID)).to eq(false)

    SiteSetting.ai_bot_enabled_chat_bots = "gpt-3.5-turbo"

    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT4_ID)).to eq(false)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID)).to eq(true)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID)).to eq(false)

    SiteSetting.ai_bot_enabled_chat_bots = "gpt-3.5-turbo|claude-2"

    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT4_ID)).to eq(false)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID)).to eq(true)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID)).to eq(true)

    SiteSetting.ai_bot_enabled = false

    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT4_ID)).to eq(false)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID)).to eq(false)
    expect(User.exists?(id: DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID)).to eq(false)
  end

  it "leaves accounts around if they have any posts" do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"

    user = User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID)

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
