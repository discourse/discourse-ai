# frozen_string_literal: true

describe Jobs::PostLocalizationBackfill do
  before do
    SiteSetting.ai_translation_backfill_rate = 100
    SiteSetting.experimental_content_localization_supported_locales = "en"
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end
  end

  it "does not enqueue post translation when translator disabled" do
    SiteSetting.discourse_ai_enabled = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "does not enqueue post translation when experimental translation disabled" do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "does not enqueue psot translation if backfill languages are not set" do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    SiteSetting.experimental_content_localization_supported_locales = ""

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "does not enqueue post translation if backfill limit is set to 0" do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_rate = 0

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "enqueues post translation with correct limit" do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_rate = 10

    described_class.new.execute({})

    expect_job_enqueued(job: :localize_posts, args: { limit: 10 })
  end
end
