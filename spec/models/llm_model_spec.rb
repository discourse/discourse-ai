# frozen_string_literal: true

RSpec.describe LlmModel do
  describe ".seed_srv_backed_model" do
    before do
      SiteSetting.ai_vllm_endpoint_srv = "srv.llm.service."
      SiteSetting.ai_vllm_api_key = "123"
    end

    context "when the model doesn't exist yet" do
      it "creates it" do
        described_class.seed_srv_backed_model

        llm_model = described_class.find_by(url: described_class::RESERVED_VLLM_SRV_URL)

        expect(llm_model).to be_present
        expect(llm_model.name).to eq("Qwen/Qwen2-72B-Instruct-GPTQ-Int8")
        expect(llm_model.api_key).to eq(SiteSetting.ai_vllm_api_key)
      end
    end

    context "when the model already exists" do
      before { described_class.seed_srv_backed_model }

      context "when the API key setting changes" do
        it "updates it" do
          new_key = "456"
          SiteSetting.ai_vllm_api_key = new_key

          described_class.seed_srv_backed_model

          llm_model = described_class.find_by(url: described_class::RESERVED_VLLM_SRV_URL)

          expect(llm_model.api_key).to eq(new_key)
        end
      end

      context "when the SRV is no longer defined" do
        it "deletes the LlmModel" do
          llm_model = described_class.find_by(url: described_class::RESERVED_VLLM_SRV_URL)
          expect(llm_model).to be_present

          SiteSetting.ai_vllm_endpoint_srv = "" # Triggers seed code

          expect { llm_model.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        end

        it "disabled the bot user" do
          SiteSetting.ai_bot_enabled = true
          llm_model = described_class.find_by(url: described_class::RESERVED_VLLM_SRV_URL)
          llm_model.update!(enabled_chat_bot: true)
          llm_model.toggle_companion_user
          user = llm_model.user

          expect(user).to be_present

          SiteSetting.ai_vllm_endpoint_srv = "" # Triggers seed code

          expect { user.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
