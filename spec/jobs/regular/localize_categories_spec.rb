# frozen_string_literal: true

describe Jobs::LocalizeCategories do
  subject(:job) { described_class.new }

  def localize_all_categories(*locales)
    Category.all.each do |category|
      locales.each { |locale| Fabricate(:category_localization, category:, locale:, name: "x") }
    end
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_translation_enabled = true
    SiteSetting.experimental_content_localization_supported_locales = "pt|zh_CN"

    Jobs.run_immediately!
  end

  it "does nothing when DiscourseAi::Translation::CategoryLocalizer is disabled" do
    SiteSetting.discourse_ai_enabled = false

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({})
  end

  it "does nothing when ai_translation_enabled is disabled" do
    SiteSetting.ai_translation_enabled = false

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({})
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.experimental_content_localization_supported_locales = ""

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({})
  end

  it "does nothing when no categories exist" do
    Category.destroy_all

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({})
  end

  it "translates categories to the configured locales" do
    Category.update_all(locale: "en")
    number_of_categories = Category.count

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(is_a(Category), "pt")
      .times(number_of_categories)
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(is_a(Category), "zh_CN")
      .times(number_of_categories)

    job.execute({})
  end

  it "skips categories that already have localizations" do
    localize_all_categories("pt", "zh_CN")

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).with(is_a(Category), "pt").never
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(is_a(Category), "zh_CN")
      .never

    job.execute({})
  end

  it "continues from a specified category ID" do
    category1 = Fabricate(:category, name: "First", description: "First description", locale: "en")
    category2 =
      Fabricate(:category, name: "Second", description: "Second description", locale: "en")

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(category1, any_parameters)
      .never
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(category2, any_parameters)
      .twice

    job.execute(from_category_id: category2.id)
  end

  it "handles translation errors gracefully" do
    localize_all_categories("pt", "zh_CN")

    category1 = Fabricate(:category, name: "First", description: "First description", locale: "en")
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(category1, "pt")
      .raises(StandardError.new("API error"))
    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).with(category1, "zh_CN").once

    expect { job.execute({}) }.not_to raise_error
  end

  it "enqueues the next batch when there are more categories" do
    Category.update_all(locale: "en")

    Jobs.run_later!
    freeze_time
    Jobs::LocalizeCategories.const_set(:BATCH_SIZE, 1)

    job.execute({})

    Category.all.each do |category|
      puts category.id
      expect_job_enqueued(
        job: :localize_categories,
        args: {
          from_category_id: category.id + 1,
        },
        at: 10.seconds.from_now,
      )
    end

    Jobs::LocalizeCategories.send(:remove_const, :BATCH_SIZE)
    Jobs::LocalizeCategories.const_set(:BATCH_SIZE, 50)
  end

  it "skips read-restricted categories when configured" do
    SiteSetting.ai_translation_backfill_limit_to_public_content = true

    category1 = Fabricate(:category, name: "Public Category", read_restricted: false, locale: "en")
    category2 = Fabricate(:category, name: "Private Category", read_restricted: true, locale: "en")

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(category1, any_parameters)
      .twice
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(category2, any_parameters)
      .never

    job.execute({})
  end

  it "skips creating localizations in the same language as the category's locale" do
    Category.update_all(locale: "pt")

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).with(is_a(Category), "pt").never
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(is_a(Category), "zh_CN")
      .times(Category.count)

    job.execute({})
  end

  it "deletes existing localizations that match the category's locale" do
    # update all categories to portuguese
    Category.update_all(locale: "pt")

    localize_all_categories("pt", "zh_CN")

    expect { job.execute({}) }.to change { CategoryLocalization.exists?(locale: "pt") }.from(
      true,
    ).to(false)
  end

  it "doesn't process categories with nil locale" do
    # Add a category with nil locale
    nil_locale_category = Fabricate(:category, name: "No Locale", locale: nil)

    # Make sure our query for categories with non-null locales excludes it
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(nil_locale_category, any_parameters)
      .never

    job.execute({})
  end
end
