# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiToolsController do
  fab!(:admin)
  fab!(:ai_tool) do
    AiTool.create!(
      name: "Test Tool",
      description: "A test tool",
      script: "function invoke(params) { return params; }",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      summary: "Test tool summary",
      details: "Test tool details",
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
        summary: "Test tool summary",
        details: "Test tool details",
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

  describe "#test" do
    it "runs an existing tool and returns the result" do
      post "/admin/plugins/discourse-ai/ai-tools/test.json",
           params: {
             id: ai_tool.id,
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["output"]).to eq("input" => "Hello, World!")
    end

    it "runs a new unsaved tool and returns the result" do
      post "/admin/plugins/discourse-ai/ai-tools/test.json",
           params: {
             ai_tool: {
               name: "New Tool",
               description: "A new test tool",
               script: "function invoke(params) { return 'New test result: ' + params.input; }",
               parameters: [
                 { name: "input", type: "string", description: "Input for the new test tool" },
               ],
             },
             parameters: {
               input: "Test input",
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["output"]).to eq("New test result: Test input")
    end

    it "returns an error for invalid tool_id" do
      post "/admin/plugins/discourse-ai/ai-tools/test.json",
           params: {
             id: -1,
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to include("Couldn't find AiTool with 'id'=-1")
    end

    it "handles exceptions during tool execution" do
      ai_tool.update!(script: "function invoke(params) { throw new Error('Test error'); }")

      post "/admin/plugins/discourse-ai/ai-tools/test.json",
           params: {
             id: ai_tool.id,
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].to_s).to include("Error executing the tool")
    end
  end
end
