# frozen_string_literal: true

RSpec.describe Jobs::UpdateAiBotPmTitle do
  let(:user) { Fabricate(:admin) }

  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model("claude-2") }

  before do
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
  end

  it "will properly update title on bot PMs" do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:staff]

    post =
      create_post(
        user: user,
        raw: "Hello there",
        title: "does not matter should be updated",
        archetype: Archetype.private_message,
        target_usernames: bot_user.username,
      )

    title_result = "A great title would be:\n\nMy amazing title\n\n"

    DiscourseAi::Completions::Llm.with_prepared_responses([title_result]) do
      subject.execute(bot_user_id: bot_user.id, post_id: post.id)

      expect(post.reload.topic.title).to eq("My amazing title")
    end

    another_title = "I'm a different title"

    DiscourseAi::Completions::Llm.with_prepared_responses([another_title]) do
      subject.execute(bot_user_id: bot_user.id, post_id: post.id)

      expect(post.reload.topic.title).to eq("My amazing title")
    end
  end
end
