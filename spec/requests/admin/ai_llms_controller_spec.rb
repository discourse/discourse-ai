# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiLlmsController do
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.ai_bot_enabled = true
  end

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
          url: "https://test.test/v1/chat/completions",
          api_key: "test",
          tokenizer: "DiscourseAi::Tokenizer::OpenAiTokenizer",
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

      it "creates a companion user" do
        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.merge(enabled_chat_bot: true),
             }

        created_model = LlmModel.last

        expect(created_model.user_id).to be_present
      end

      it "stores provider-specific config params" do
        provider_params = { organization: "Discourse" }

        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.merge(provider_params: provider_params),
             }

        created_model = LlmModel.last

        expect(created_model.lookup_custom_param("organization")).to eq(
          provider_params[:organization],
        )
      end

      it "ignores parameters not associated with that provider" do
        provider_params = { access_key_id: "random_key" }

        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.merge(provider_params: provider_params),
             }

        created_model = LlmModel.last

        expect(created_model.lookup_custom_param("access_key_id")).to be_nil
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

      it "creates a companion user" do
        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: update_attrs.merge(enabled_chat_bot: true),
            }

        expect(llm_model.reload.user_id).to be_present
      end

      it "removes the companion user when desabling the chat bot option" do
        llm_model.update!(enabled_chat_bot: true)
        llm_model.toggle_companion_user

        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: update_attrs.merge(enabled_chat_bot: false),
            }

        expect(llm_model.reload.user_id).to be_nil
      end
    end

    context "with provider-specific params" do
      it "updates provider-specific config params" do
        provider_params = { organization: "Discourse" }

        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: {
                provider_params: provider_params,
              },
            }

        expect(llm_model.reload.lookup_custom_param("organization")).to eq(
          provider_params[:organization],
        )
      end

      it "ignores parameters not associated with that provider" do
        provider_params = { access_key_id: "random_key" }

        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: {
                provider_params: provider_params,
              },
            }

        expect(llm_model.reload.lookup_custom_param("access_key_id")).to be_nil
      end
    end
  end

  describe "GET #test" do
    let(:test_attrs) do
      {
        name: "llama3",
        provider: "hugging_face",
        url: "https://test.test/v1/chat/completions",
        api_key: "test",
        tokenizer: "DiscourseAi::Tokenizer::Llama3Tokenizer",
        max_prompt_tokens: 2_000,
      }
    end

    context "when we can contact the model" do
      it "returns a success true flag" do
        DiscourseAi::Completions::Llm.with_prepared_responses(["a response"]) do
          get "/admin/plugins/discourse-ai/ai-llms/test.json", params: { ai_llm: test_attrs }

          expect(response).to be_successful
          expect(response.parsed_body["success"]).to eq(true)
        end
      end
    end

    context "when we cannot contact the model" do
      it "returns a success false flag and the error message" do
        error_message = {
          error:
            "Input validation error: `inputs` tokens + `max_new_tokens` must be <= 1512. Given: 30 `inputs` tokens and 3984 `max_new_tokens`",
          error_type: "validation",
        }

        WebMock.stub_request(:post, test_attrs[:url]).to_return(
          status: 422,
          body: error_message.to_json,
        )

        get "/admin/plugins/discourse-ai/ai-llms/test.json", params: { ai_llm: test_attrs }

        expect(response).to be_successful
        expect(response.parsed_body["success"]).to eq(false)
        expect(response.parsed_body["error"]).to eq(error_message.to_json)
      end
    end
  end

  describe "DELETE #destroy" do
    fab!(:llm_model)

    it "destroys the requested ai_persona" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(LlmModel, :count).by(-1)
    end

    it "validates the model is not in use" do
      fake_llm = assign_fake_provider_to(:ai_helper_model)

      delete "/admin/plugins/discourse-ai/ai-llms/#{fake_llm.id}.json"

      expect(response.status).to eq(409)
      expect(fake_llm.reload).to eq(fake_llm)
    end

    it "cleans up companion users before deleting the model" do
      llm_model.update!(enabled_chat_bot: true)
      llm_model.toggle_companion_user
      companion_user = llm_model.user

      delete "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json"

      expect { companion_user.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
