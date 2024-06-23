# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiToolsController do
  fab!(:admin)
  fab!(:ai_tool) do
    AiTool.create!(
      name: "Test Tool",
      description: "A test tool",
      script: "function invoke(params) { return params; }",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      created_by_id: -1,
    )
  end

  before do
    sign_in(admin)
    SiteSetting.ai_embeddings_enabled = true
  end

  describe "GET #index" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-tools.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_tools"].length).to eq(AiTool.count)
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_tool"]["name"]).to eq(ai_tool.name)
    end
  end

  describe "POST #create" do
    let(:valid_attributes) do
      {
        name: "Test Tool",
        description: "A test tool",
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
        script: "function invoke(params) { return params; }",
      }
    end

    it "creates a new AiTool" do
      expect {
        post "/admin/plugins/discourse-ai/ai-tools.json",
             params: { ai_tool: valid_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.to change(AiTool, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["ai_tool"]["name"]).to eq("Test Tool")
    end
  end

  describe "PUT #update" do
    it "updates the requested ai_tool" do
      put "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json",
          params: {
            ai_tool: {
              name: "Updated Tool",
            },
          }

      expect(response).to be_successful
      expect(ai_tool.reload.name).to eq("Updated Tool")
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested ai_tool" do
      expect { delete "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json" }.to change(
        AiTool,
        :count,
      ).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
