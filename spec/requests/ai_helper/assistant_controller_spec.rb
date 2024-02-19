# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::AssistantController do
  before { SiteSetting.ai_helper_model = "fake:fake" }

  describe "#suggest" do
    let(:text_to_proofread) { "The rain in spain stays mainly in the plane." }
    let(:proofread_text) { "The rain in Spain, stays mainly in the Plane." }
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
          .expects(:generate)
          .raises(DiscourseAi::Completions::Endpoints::Base::CompletionFailed)

        post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text_to_proofread }

        expect(response.status).to eq(502)
      end

      it "returns a suggestion" do
        expected_diff =
          "<div class=\"inline-diff\"><p>The rain in <ins>Spain</ins><ins>,</ins><ins> </ins><del>spain </del>stays mainly in the <ins>Plane</ins><del>plane</del>.</p></div>"

        DiscourseAi::Completions::Llm.with_prepared_responses([proofread_text]) do
          post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text_to_proofread }

          expect(response.status).to eq(200)
          expect(response.parsed_body["suggestions"].first).to eq(proofread_text)
          expect(response.parsed_body["diff"]).to eq(expected_diff)
        end
      end

      it "uses custom instruction when using custom_prompt mode" do
        translated_text = "Un usuario escribio esto"
        expected_diff =
          "<div class=\"inline-diff\"><p><ins>Un </ins><ins>usuario </ins><ins>escribio </ins><ins>esto</ins><del>A </del><del>user </del><del>wrote </del><del>this</del></p></div>"

        expected_input = <<~TEXT.strip
        <input>Translate to Spanish:
        A user wrote this</input>
        TEXT

        DiscourseAi::Completions::Llm.with_prepared_responses([translated_text]) do
          post "/discourse-ai/ai-helper/suggest",
               params: {
                 mode: CompletionPrompt::CUSTOM_PROMPT,
                 text: "A user wrote this",
                 custom_prompt: "Translate to Spanish",
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body["suggestions"].first).to eq(translated_text)
          expect(response.parsed_body["diff"]).to eq(expected_diff)
        end
      end
    end
  end

  describe "#caption_image" do
    let(:image_url) { "https://example.com/image.jpg" }
    let(:caption) { "A picture of a cat sitting on a table" }

    context "when logged in as an allowed user" do
      fab!(:user)

      before do
        sign_in(user)
        user.group_ids = [Group::AUTO_GROUPS[:trust_level_1]]
        SiteSetting.ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
        SiteSetting.ai_llava_endpoint = "https://example.com"

        stub_request(:post, "https://example.com/predictions").to_return(
          status: 200,
          body: { output: caption.gsub(" ", " |").split("|") }.to_json,
        )
      end

      it "returns the suggested caption for the image" do
        post "/discourse-ai/ai-helper/caption_image", params: { image_url: image_url }

        expect(response.status).to eq(200)
        expect(response.parsed_body["caption"]).to eq(caption)
      end

      it "returns a 502 error when the completion call fails" do
        stub_request(:post, "https://example.com/predictions").to_return(
          status: 502
        )

        post "/discourse-ai/ai-helper/caption_image", params: { image_url: image_url }

        expect(response.status).to eq(502)
      end

      it "returns a 400 error when the image_url is blank" do
        post "/discourse-ai/ai-helper/caption_image"

        expect(response.status).to eq(400)
      end
    end
  end
end
