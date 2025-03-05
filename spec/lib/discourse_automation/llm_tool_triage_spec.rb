# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Automation::LlmToolTriage do
  fab!(:solver) { Fabricate(:user) }
  fab!(:new_user) { Fabricate(:user, trust_level: TrustLevel[0], created_at: 1.day.ago) }
  fab!(:topic) { Fabricate(:topic, user: new_user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: new_user, raw: "How do I reset my password?") }
  fab!(:llm_model)
  fab!(:ai_persona) do
    persona = Fabricate(:ai_persona, default_llm: llm_model)
    persona.create_user
    persona
  end

  fab!(:tool) do
    tool_script = <<~JS
      function invoke(params) {
        const postId = context.post_id;
        const post = discourse.getPost(postId);
        const user = discourse.getUser(post.user_id);

        if (user.trust_level > 0) {
          return {
            processed: false,
            reason: "User is not new"
          };
        }

        const helper = discourse.getPersona("#{ai_persona.name}");
        const answer = helper.respondTo({ post_id: post.id });

        return {
          answer: answer,
          processed: true,
          reason: "answered question"
        };
      }
    JS

    AiTool.create!(
      name: "New User Question Answerer",
      tool_name: "new_user_question_answerer",
      description: "Automatically answers questions from new users when possible",
      parameters: [], # No parameters as required by llm_tool_triage
      script: tool_script,
      created_by_id: Discourse.system_user.id,
      summary: "Answers new user questions",
      enabled: true,
    )
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_bot_enabled = true
  end

  it "It is able to answer new user questions" do
    result = nil
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["this is how you reset your password"],
    ) { result = described_class.handle(post: post, tool_id: tool.id) }
    expect(result["processed"]).to eq(true)
    response = post.topic.reload.posts.order(:post_number).last
    expect(response.raw).to eq("this is how you reset your password")
  end
end
