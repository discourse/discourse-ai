# frozen_string_literal: true
require "rails_helper"

RSpec.describe DiscourseAi::Admin::AiPersonasController do
  fab!(:admin)
  fab!(:ai_persona)

  before { sign_in(admin) }

  describe "GET #index" do
    it "returns a success response" do
      get "/admin/plugins/ai/ai_personas"
      expect(response).to be_successful
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      get "/admin/plugins/ai/ai_personas/#{ai_persona.id}.json"
      expect(response).to be_successful
      expect(response.parsed_body["name"]).to eq(ai_persona.name)
    end
  end

  describe "POST #create" do
    context "with valid params" do
      let(:valid_attributes) do
        {
          name: "superbot",
          description: "Assists with tasks",
          system_prompt: "you are a helpful bot",
        }
      end

      it "creates a new AiPersona" do
        expect {
          post "/admin/plugins/ai/ai_personas.json", params: { ai_persona: valid_attributes }
          expect(response).to be_successful
        }.to change(AiPersona, :count).by(1)
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new ai_persona" do
        post "/admin/plugins/ai/ai_personas.json", params: { ai_persona: { foo: "" } } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      it "updates the requested ai_persona" do
        put "/admin/plugins/ai/ai_personas/#{ai_persona.id}.json",
            params: {
              ai_persona: {
                name: "SuperBot",
              },
            }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")

        ai_persona.reload
        expect(ai_persona.name).to eq("SuperBot")
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the ai_persona" do
        put "/admin/plugins/ai/ai_personas/#{ai_persona.id}.json",
            params: {
              ai_persona: {
                name: "",
              },
            } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested ai_persona" do
      expect {
        delete "/admin/plugins/ai/ai_personas/#{ai_persona.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(AiPersona, :count).by(-1)
    end
  end
end
