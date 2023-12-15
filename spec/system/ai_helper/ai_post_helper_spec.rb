# frozen_string_literal: true

RSpec.describe "AI Post helper", type: :system, js: true do
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
    Fabricate(:post, topic: topic, raw: "La lluvia en España se queda principalmente en el avión.")
  end
  fab!(:post_3) do
    Fabricate(
      :post,
      topic: topic,
      raw:
        "The Toyota Supra delivrs 382 horsepwr makin it a very farst car.",
    )
  end
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:post_ai_helper) { PageObjects::Components::AIHelperPostOptions.new }
  let(:fast_editor) { PageObjects::Components::FastEditor.new }

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
      let(:mode) { CompletionPrompt::EXPLAIN }

      let(:explain_response) { <<~STRING }
        In this context, \"pie\" refers to a baked dessert typically consisting of a pastry crust and filling.
        The person states they enjoy eating pie, considering it a good dessert. They note that some people wastefully
        throw pie at others, but the person themselves chooses to eat the pie rather than throwing it. Overall, \"pie\"
        is being used to refer the the baked dessert food item.
      STRING

      skip "TODO: Fix explain option stuck in loading in test" do
        it "shows an explanation of the selected text" do
          select_post_text(post)
          post_ai_helper.click_ai_button

          DiscourseAi::Completions::Llm.with_prepared_responses([explain_response]) do
            post_ai_helper.select_helper_model(mode)
            wait_for { post_ai_helper.suggestion_value == explain_response }
            expect(post_ai_helper.suggestion_value).to eq(explain_response)
          end
        end
      end
    end

    context "when using translate mode" do
      let(:mode) { CompletionPrompt::TRANSLATE }

      let(:translated_input) { "The rain in Spain, stays mainly in the Plane." }

      it "shows a translation of the selected text" do
        select_post_text(post_2)
        post_ai_helper.click_ai_button

        DiscourseAi::Completions::Llm.with_prepared_responses([translated_input]) do
          post_ai_helper.select_helper_model(mode)

          wait_for { post_ai_helper.suggestion_value == translated_input }

          expect(post_ai_helper.suggestion_value).to eq(translated_input)
        end
      end
    end

    context "when using proofread mode" do
      let(:mode) { CompletionPrompt::PROOFREAD }
      let(:proofread_response) { "The Toyota Supra delivers 382 horsepower making it a very fast car." }

      it "pre-fills fast edit with proofread text" do
        select_post_text(post_3)
        post_ai_helper.click_ai_button
        DiscourseAi::Completions::Llm.with_prepared_responses([proofread_response]) do
          post_ai_helper.select_helper_model(mode)
          wait_for { fast_editor.has_content?(proofread_response) }
          expect(fast_editor).to have_content(proofread_response)
        end
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

  context "when triggering AI proofread through edit button" do
    let(:proofread_response) { "The Toyota Supra delivers 382 horsepower making it a very fast car." }

    it "pre-fills fast edit with proofread text" do
      select_post_text(post_3)
      find(".quote-edit-label").click
      DiscourseAi::Completions::Llm.with_prepared_responses([proofread_response]) do
        find(".btn-ai-suggest-edit", visible: :all).click
        wait_for { fast_editor.has_content?(proofread_response) }
        expect(fast_editor).to have_content(proofread_response)
      end
    end
  end
end
