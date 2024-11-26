# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiToolsController do
  fab!(:admin)
  fab!(:ai_tool) do
    AiTool.create!(
      name: "Test Tool",
      tool_name: "test_tool",
      description: "A test tool",
      script: "function invoke(params) { return params; }",
      parameters: [
        {
          name: "unit",
          type: "string",
          description: "the unit of measurement celcius c or fahrenheit f",
          enum: %w[c f],
          required: true,
        },
      ],
      summary: "Test tool summary",
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
      expect(response.parsed_body["meta"]["presets"].length).to be > 0
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
        name: "Test Tool 1",
        tool_name: "test_tool_1",
        description: "A test tool",
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
        script: "function invoke(params) { return params; }",
        summary: "Test tool summary",
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
      expect(response.parsed_body["ai_tool"]["name"]).to eq("Test Tool 1")
      expect(response.parsed_body["ai_tool"]["tool_name"]).to eq("test_tool_1")
    end

    context "when the parameter is a enum" do
      it "creates the tool with the correct parameters" do
        attrs = valid_attributes
        attrs[:parameters] = [attrs[:parameters].first.merge(enum: %w[c f])]

        expect {
          post "/admin/plugins/discourse-ai/ai-tools.json",
               params: { ai_tool: valid_attributes }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
        }.to change(AiTool, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body.dig("ai_tool", "parameters", 0, "enum")).to contain_exactly(
          "c",
          "f",
        )
      end
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

    context "when updating an enum parameters" do
      it "updates the enum fixed values" do
        put "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json",
            params: {
              ai_tool: {
                parameters: [
                  {
                    name: "unit",
                    type: "string",
                    description: "the unit of measurement celcius c or fahrenheit f",
                    enum: %w[g d],
                  },
                ],
              },
            }

        expect(response).to be_successful
        expect(ai_tool.reload.parameters.dig(0, "enum")).to contain_exactly("g", "d")
      end
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
      post "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/test.json",
           params: {
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["output"]).to eq("input" => "Hello, World!")
    end

    it "accept changes to the ai_tool parameters that redefine stuff" do
      post "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/test.json",
           params: {
             ai_tool: {
               script: "function invoke(params) { return 'hi there'; }",
             },
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["output"]).to eq("hi there")
    end

    it "returns an error for invalid tool_id" do
      post "/admin/plugins/discourse-ai/ai-tools/-1/test.json",
           params: {
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(404)
    end

    it "handles exceptions during tool execution" do
      ai_tool.update!(script: "function invoke(params) { throw new Error('Test error'); }")

      post "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/test.json",
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
