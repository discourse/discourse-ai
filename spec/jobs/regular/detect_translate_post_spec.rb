# frozen_string_literal: true

describe Jobs::DetectTranslatePost do
  fab!(:post)
  subject(:job) { described_class.new }

  let(:locales) { %w[en ja] }

  before do
    SiteSetting.discourse_ai_enabled = true
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_translation_enabled = true
    SiteSetting.experimental_content_localization_supported_locales = locales.join("|")
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "detects locale" do
    SiteSetting.discourse_ai_enabled = true
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).once
    DiscourseAi::Translation::PostLocalizer.expects(:localize).twice

    job.execute({ post_id: post.id })
  end

  it "skips locale detection when post has a locale" do
    post.update!(locale: "en")
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).with(post, "ja").once

    job.execute({ post_id: post.id })
  end

  it "skips bot posts" do
    post.update!(user: Discourse.system_user)
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "does not translate when no target languages are configured" do
    SiteSetting.experimental_content_localization_supported_locales = ""
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).returns("en")
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "skips translating to the post's language" do
    post.update(locale: "en")
    DiscourseAi::Translation::PostLocalizer.expects(:localize).with(post, "en").never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).with(post, "ja").once

    job.execute({ post_id: post.id })
  end

  it "skips translating if the post is already localized" do
    post.update(locale: "en")
    Fabricate(:post_localization, post: post, locale: "ja")

    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "handles translation errors gracefully" do
    post.update(locale: "en")
    DiscourseAi::Translation::PostLocalizer.expects(:localize).raises(
      StandardError.new("API error"),
    )

    expect { job.execute({ post_id: post.id }) }.not_to raise_error
  end

  it "skips public content when `ai_translation_backfill_limit_to_public_content ` site setting is enabled" do
    SiteSetting.ai_translation_backfill_limit_to_public_content = true
    post.topic.category.update!(read_restricted: true)

    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })

    pm_post = Fabricate(:post, topic: Fabricate(:private_message_topic))
    job.execute({ post_id: pm_post.id })
  end
end
