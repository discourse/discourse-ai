# frozen_string_literal: true
describe DiscourseAi::Automation::LlmTriage do
  fab!(:post)
  fab!(:reply) { Fabricate(:post, topic: post.topic, user: Fabricate(:user)) }
  fab!(:llm_model)

  def triage(**args)
    DiscourseAi::Automation::LlmTriage.handle(**args)
  end

  it "does nothing if it does not pass triage" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["good"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        hide_topic: true,
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        automation: nil,
      )
    end

    expect(post.topic.reload.visible).to eq(true)
  end

  it "can hide topics on triage" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        hide_topic: true,
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        automation: nil,
      )
    end

    expect(post.topic.reload.visible).to eq(false)
  end

  it "can categorize topics on triage" do
    category = Fabricate(:category)

    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        category_id: category.id,
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        automation: nil,
      )
    end

    expect(post.topic.reload.category_id).to eq(category.id)
  end

  it "can reply to topics on triage" do
    user = Fabricate(:user)
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        canned_reply: "test canned reply 123",
        canned_reply_user: user.username,
        automation: nil,
      )
    end

    reply = post.topic.posts.order(:post_number).last

    expect(reply.raw).to eq("test canned reply 123")
    expect(reply.user.id).to eq(user.id)
  end

  it "can add posts to the review queue" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        flag_post: true,
        automation: nil,
      )
    end

    reviewable = ReviewablePost.last

    expect(reviewable.target).to eq(post)
    expect(reviewable.reviewable_scores.first.reason).to include("bad")
  end

  it "can handle spam flags" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        flag_post: true,
        flag_type: :spam,
        automation: nil,
      )
    end

    expect(post.reload).to be_hidden
    expect(post.topic.reload.visible).to eq(false)
  end

  it "can handle spam+silence flags" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        flag_post: true,
        flag_type: :spam_silence,
        automation: nil,
      )
    end

    expect(post.reload).to be_hidden
    expect(post.topic.reload.visible).to eq(false)
    expect(post.user.silenced?).to eq(true)
  end

  it "can handle garbled output from LLM" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["Bad.\n\nYo"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        flag_post: true,
        automation: nil,
      )
    end

    reviewable = ReviewablePost.last

    expect(reviewable&.target).to eq(post)
  end

  it "treats search_for_text as case-insensitive" do
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        system_prompt: "test %%POST%%",
        search_for_text: "BAD",
        flag_post: true,
        automation: nil,
      )
    end

    reviewable = ReviewablePost.last

    expect(reviewable.target).to eq(post)
  end

  it "includes post uploads when triaging" do
    post_upload = Fabricate(:image_upload, posts: [post])

    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      triage(
        post: post,
        model: "custom:#{llm_model.id}",
        system_prompt: "test %%POST%%",
        search_for_text: "bad",
        flag_post: true,
        automation: nil,
      )

      triage_prompt = DiscourseAi::Completions::Llm.prompts.last

      expect(triage_prompt.messages.last[:upload_ids]).to contain_exactly(post_upload.id)
    end
  end
end
