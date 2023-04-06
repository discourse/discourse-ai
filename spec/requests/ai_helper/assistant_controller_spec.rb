# frozen_string_literal: true

require_relative "../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiHelper::AssistantController do
  describe "#suggest" do
    let(:text) { OpenAiCompletionsInferenceStubs.translated_response }
    let(:mode) { "-3" }

    context "when not logged in" do
      it "returns a 403 response" do
        post "/discourse-ai/ai-helper/suggest", params: { text: text, mode: mode }

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
        post "/discourse-ai/ai-helper/suggest", params: { text: text, mode: mode }

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

        post "/discourse-ai/ai-helper/suggest", params: { text: text, mode: invalid_mode }

        expect(response.status).to eq(400)
      end

      it "returns a 400 if the text is blank" do
        post "/discourse-ai/ai-helper/suggest", params: { mode: mode }

        expect(response.status).to eq(400)
      end

      it "returns a generic error when the completion call fails" do
        WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
        )

        post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text }

        expect(response.status).to eq(502)
      end

      it "returns a suggestion" do
        OpenAiCompletionsInferenceStubs.stub_prompt("proofread")

        post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text }

        expect(response.status).to eq(200)
        expect(response.parsed_body["suggestions"].first).to eq(
          OpenAiCompletionsInferenceStubs.proofread_response.strip,
        )
      end
    end
  end
end
