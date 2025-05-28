# frozen_string_literal: true

describe Jobs::DetectTranslateTopic do
  fab!(:topic)
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
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "detects locale" do
    SiteSetting.discourse_ai_enabled = true
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).once
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).twice

    job.execute({ topic_id: topic.id })
  end

  it "skips bot topics" do
    topic.update!(user: Discourse.system_user)
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "does not translate when no target languages are configured" do
    SiteSetting.experimental_content_localization_supported_locales = ""
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).returns("en")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "skips translating to the topic's language" do
    topic.update(locale: "en")
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).returns("en")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "en").never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").once

    job.execute({ topic_id: topic.id })
  end

  it "handles translation errors gracefully" do
    topic.update(locale: "en")
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).returns("en")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).raises(
      StandardError.new("API error"),
    )

    expect { job.execute({ topic_id: topic.id }) }.not_to raise_error
  end

  it "skips public content when `ai_translation_backfill_limit_to_public_content ` site setting is enabled" do
    SiteSetting.ai_translation_backfill_limit_to_public_content = true
    topic.category.update!(read_restricted: true)

    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end
end
