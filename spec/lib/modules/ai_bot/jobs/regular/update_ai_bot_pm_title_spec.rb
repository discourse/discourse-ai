# frozen_string_literal: true

RSpec.describe Jobs::UpdateAiBotPmTitle do
  let(:user) { Fabricate(:admin) }
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID) }

  before do
    SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
    SiteSetting.ai_bot_enabled = true
  end

  it "will properly update title on bot PMs" do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:staff]

    Jobs.run_immediately!

    WebMock
      .stub_request(:post, "https://api.anthropic.com/v1/complete")
      .with(body: /You are a helpful Discourse assistant/)
      .to_return(status: 200, body: "data: {\"completion\": \"Hello back at you\"}", headers: {})

    WebMock
      .stub_request(:post, "https://api.anthropic.com/v1/complete")
      .with(body: /Suggest a 7 word title/)
      .to_return(
        status: 200,
        body: "{\"completion\": \"A great title would be:\n\nMy amazing title\n\n\"}",
        headers: {
        },
      )

    post =
      create_post(
        user: user,
        raw: "Hello there",
        title: "does not matter should be updated",
        archetype: Archetype.private_message,
        target_usernames: bot_user.username,
      )

    expect(post.reload.topic.title).to eq("My amazing title")

    WebMock.reset!

    Jobs::UpdateAiBotPmTitle.new.execute(bot_user_id: bot_user.id, post_id: post.id)
    # should be a no op cause title is updated
  end
end
