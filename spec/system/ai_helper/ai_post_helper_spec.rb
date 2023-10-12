# frozen_string_literal: true

require_relative "../../support/openai_completions_inference_stubs"

RSpec.describe "AI Composer helper", type: :system, js: true do
  fab!(:user) { Fabricate(:admin) }
  fab!(:non_member_group) { Fabricate(:group) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) do
    Fabricate(
      :post,
      topic: topic,
      raw:
        "I like to eat pie. It is a very good dessert. Some people are wasteful by throwing pie at others but I do not do that. I always eat the pie.",
    )
  end
  fab!(:post_2) do
    Fabricate(:post, topic: topic, raw: OpenAiCompletionsInferenceStubs.spanish_text)
  end
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:post_ai_helper) { PageObjects::Components::AIHelperPostOptions.new }

  before do
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    SiteSetting.composer_ai_helper_enabled = true
    sign_in(user)
  end

  def select_post_text(selected_post)
    topic_page.visit_topic(topic)
    page.execute_script(
      "var element = document.querySelector('#{topic_page.post_by_number_selector(selected_post.post_number)} .cooked p'); " +
        "var range = document.createRange(); " + "range.selectNodeContents(element); " +
        "var selection = window.getSelection(); " + "selection.removeAllRanges(); " +
        "selection.addRange(range);",
    )
  end

  context "when triggering AI helper in post" do
    it "shows the Ask AI button in the post selection toolbar" do
      select_post_text(post)
      expect(post_ai_helper).to have_post_selection_toolbar
      expect(post_ai_helper).to have_post_ai_helper
    end

    it "shows AI helper options after clicking the AI button" do
      select_post_text(post)
      post_ai_helper.click_ai_button
      expect(post_ai_helper).to have_no_post_selection_primary_buttons
      expect(post_ai_helper).to have_post_ai_helper_options
    end

    context "when using explain mode" do
      let(:mode) { OpenAiCompletionsInferenceStubs::EXPLAIN }

      it "shows an explanation of the selected text" do
        select_post_text(post)
        post_ai_helper.click_ai_button
        post_ai_helper.select_helper_model(OpenAiCompletionsInferenceStubs.text_mode_to_id(mode))

        wait_for do
          post_ai_helper.suggestion_value == OpenAiCompletionsInferenceStubs.explain_response.strip
        end

        expect(post_ai_helper.suggestion_value).to eq(
          OpenAiCompletionsInferenceStubs.explain_response.strip,
        )
      end
    end

    context "when using translate mode" do
      let(:mode) { OpenAiCompletionsInferenceStubs::TRANSLATE }

      it "shows a translation of the selected text" do
        select_post_text(post_2)
        post_ai_helper.click_ai_button
        post_ai_helper.select_helper_model(OpenAiCompletionsInferenceStubs.text_mode_to_id(mode))

        wait_for do
          post_ai_helper.suggestion_value ==
            OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        expect(post_ai_helper.suggestion_value).to eq(
          OpenAiCompletionsInferenceStubs.translated_response.strip,
        )
      end
    end
  end

  context "when AI helper is disabled" do
    before { SiteSetting.composer_ai_helper_enabled = false }

    it "does not show the Ask AI button in the post selection toolbar" do
      select_post_text(post)
      expect(post_ai_helper).to have_post_selection_toolbar
      expect(post_ai_helper).to have_no_post_ai_helper
    end
  end

  context "when user is not a member of the post AI helper allowed group" do
    before do
      SiteSetting.composer_ai_helper_enabled = true
      SiteSetting.post_ai_helper_allowed_groups = non_member_group.id.to_s
    end

    it "does not show the Ask AI button in the post selection toolbar" do
      select_post_text(post)
      expect(post_ai_helper).to have_post_selection_toolbar
      expect(post_ai_helper).to have_no_post_ai_helper
    end
  end
end
