# frozen_string_literal: true

RSpec.describe "Admin AI features configuration", type: :system, js: true do
  fab!(:admin)
  fab!(:llm_model)
  fab!(:summarization_persona) { Fabricate(:ai_persona) }
  fab!(:group_1) { Fabricate(:group) }
  fab!(:group_2) { Fabricate(:group) }
  let(:page_header) { PageObjects::Components::DPageHeader.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }
  let(:ai_features_page) { PageObjects::Pages::AdminAiFeatures.new }

  before do
    summarization_persona.allowed_group_ids = [group_1.id, group_2.id]
    summarization_persona.save!
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarization_persona = summarization_persona.id
    sign_in(admin)
  end

  it "lists all persona backed AI features separated by configured/unconfigured" do
    ai_features_page.visit
    expect(
      ai_features_page
        .configured_features_table
        .find(".ai-feature-list__row-item .ai-feature-list__row-item-name")
        .text,
    ).to eq(I18n.t("discourse_ai.features.summarization.name"))

    expect(ai_features_page).to have_configured_feature_items(1)
    expect(ai_features_page).to have_unconfigured_feature_items(3)
  end

  it "lists the persona used for the corresponding AI feature" do
    ai_features_page.visit
    expect(ai_features_page).to have_feature_persona(summarization_persona.name)
  end

  it "lists the groups allowed to use the AI feature" do
    ai_features_page.visit
    expect(ai_features_page).to have_feature_groups([group_1.name, group_2.name])
  end

  it "can navigate the AI plugin with breadcrumbs" do
    visit "/admin/plugins/discourse-ai/ai-features"
    expect(page).to have_css(".d-breadcrumbs")
    expect(page).to have_css(".d-breadcrumbs__item", count: 4)
    find(".d-breadcrumbs__item", text: I18n.t("admin_js.admin.plugins.title")).click
    expect(page).to have_current_path("/admin/plugins")
  end

  it "can edit the AI feature" do
    ai_features_page.visit
    ai_features_page.click_edit_feature(I18n.t("discourse_ai.features.summarization.name"))
    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-features/1/edit")
    expect(page).to have_css(
      ".ai-feature-editor__header h2",
      text: I18n.t("discourse_ai.features.summarization.name"),
    )

    form.field("persona_id").select(-6)
    form.submit
    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-features")
    expect(ai_features_page).to have_feature_persona(
      I18n.t("discourse_ai.ai_bot.personas.creative.name"),
    )
  end
end
