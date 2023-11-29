# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::AssistantController do
  describe "#suggest" do
    let(:text_to_proofread) { "The rain in spain stays mainly in the plane." }
    let(:proofreaded_text) { "The rain in Spain, stays mainly in the Plane." }
    let(:mode) { CompletionPrompt::PROOFREAD }

    context "when not logged in" do
      it "returns a 403 response" do
        post "/discourse-ai/ai-helper/suggest", params: { text: text_to_proofread, mode: mode }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in as an user without enough privileges" do
      fab!(:user) { Fabricate(:newuser) }

      before do
        sign_in(user)
        SiteSetting.ai_helper_allowed_groups = Group::AUTO_GROUPS[:staff]
      end

      it "returns a 403 response" do
        post "/discourse-ai/ai-helper/suggest", params: { text: text_to_proofread, mode: mode }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in as an allowed user" do
      fab!(:user) { Fabricate(:user) }

      before do
        sign_in(user)
        user.group_ids = [Group::AUTO_GROUPS[:trust_level_1]]
        SiteSetting.ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      end

      it "returns a 400 if the helper mode is invalid" do
        invalid_mode = "asd"

        post "/discourse-ai/ai-helper/suggest",
             params: {
               text: text_to_proofread,
               mode: invalid_mode,
             }

        expect(response.status).to eq(400)
      end

      it "returns a 400 if the text is blank" do
        post "/discourse-ai/ai-helper/suggest", params: { mode: mode }

        expect(response.status).to eq(400)
      end

      it "returns a generic error when the completion call fails" do
        DiscourseAi::Completions::Llm
          .any_instance
          .expects(:completion!)
          .raises(DiscourseAi::Completions::Endpoints::Base::CompletionFailed)

        post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text_to_proofread }

        expect(response.status).to eq(502)
      end

      it "returns a suggestion" do
        expected_diff =
          "<div class=\"inline-diff\"><p>The rain in <ins>Spain</ins><ins>,</ins><ins> </ins><del>spain </del>stays mainly in the <ins>Plane</ins><del>plane</del>.</p></div>"

        DiscourseAi::Completions::Llm.with_prepared_responses([proofreaded_text]) do
          post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text_to_proofread }

          expect(response.status).to eq(200)
          expect(response.parsed_body["suggestions"].first).to eq(proofreaded_text)
          expect(response.parsed_body["diff"]).to eq(expected_diff)
        end
      end
    end
  end
end
