# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiLlmsController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "GET #index" do
    it "includes all available providers metadata" do
      get "/admin/plugins/discourse-ai/ai-llms.json"
      expect(response).to be_successful

      expect(response.parsed_body["meta"]["providers"]).to contain_exactly(
        *DiscourseAi::Completions::Llm.provider_names,
      )
    end
  end

  describe "POST #create" do
    context "with valid attributes" do
      let(:valid_attrs) do
        {
          display_name: "My cool LLM",
          name: "gpt-3.5",
          provider: "open_ai",
          tokenizer: "DiscourseAi::Tokenizers::OpenAiTokenizer",
          max_prompt_tokens: 16_000,
        }
      end

      it "creates a new LLM model" do
        post "/admin/plugins/discourse-ai/ai-llms.json", params: { ai_llm: valid_attrs }

        created_model = LlmModel.last

        expect(created_model.display_name).to eq(valid_attrs[:display_name])
        expect(created_model.name).to eq(valid_attrs[:name])
        expect(created_model.provider).to eq(valid_attrs[:provider])
        expect(created_model.tokenizer).to eq(valid_attrs[:tokenizer])
        expect(created_model.max_prompt_tokens).to eq(valid_attrs[:max_prompt_tokens])
      end
    end
  end

  describe "PUT #update" do
    fab!(:llm_model)

    context "with valid update params" do
      let(:update_attrs) { { provider: "anthropic" } }

      it "updates the model" do
        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: update_attrs,
            }

        expect(response.status).to eq(200)
        expect(llm_model.reload.provider).to eq(update_attrs[:provider])
      end

      it "returns a 404 if there is no model with the given Id" do
        put "/admin/plugins/discourse-ai/ai-llms/9999999.json"

        expect(response.status).to eq(404)
      end
    end
  end
end
