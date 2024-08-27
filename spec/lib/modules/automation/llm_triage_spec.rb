# frozen_string_literal: true
describe DiscourseAi::Automation::LlmTriage do
  fab!(:post)
  fab!(:llm_model)

  def triage(**args)
    rule_args = { model: "custom:#{llm_model.id}", automation: nil, system_prompt: "test" }.merge(
      args,
    )
    DiscourseAi::Automation::LlmTriage.handle(**rule_args)
  end

  it "does nothing if it does not pass triage" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["good"]) do
      triage(post: post, hide_topic: true, search_for_text: "bad")
    end

    expect(post.topic.reload.visible).to eq(true)
  end

  it "can hide topics on triage" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(post: post, hide_topic: true, search_for_text: "bad")
    end

    expect(post.topic.reload.visible).to eq(false)
  end

  it "can categorize topics on triage" do
    category = Fabricate(:category)

    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(post: post, category_id: category.id, search_for_text: "bad")
    end

    expect(post.topic.reload.category_id).to eq(category.id)
  end

  it "can reply to topics on triage" do
    user = Fabricate(:user)
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        search_for_text: "bad",
        canned_reply: "test canned reply 123",
        canned_reply_user: user.username,
      )
    end

    reply = post.topic.posts.order(:post_number).last

    expect(reply.raw).to eq("test canned reply 123")
    expect(reply.user.id).to eq(user.id)
  end

  it "can add posts to the review queue" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(post: post, search_for_text: "bad", flag_post: true)
    end

    reviewable = ReviewablePost.last

    expect(reviewable.target).to eq(post)
    expect(reviewable.reviewable_scores.first.reason).to include("bad")
  end

  it "can handle garbled output from LLM" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["Bad.\n\nYo"]) do
      triage(post: post, search_for_text: "bad", flag_post: true)
    end

    reviewable = ReviewablePost.last

    expect(reviewable&.target).to eq(post)
  end

  it "treats search_for_text as case-insensitive" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(post: post, search_for_text: "BAD", flag_post: true)
    end

    reviewable = ReviewablePost.last

    expect(reviewable.target).to eq(post)
  end
end
