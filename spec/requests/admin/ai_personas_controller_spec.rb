# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiPersonasController do
  fab!(:admin)
  fab!(:ai_persona)

  before { sign_in(admin) }

  describe "GET #index" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai_personas.json"
      expect(response).to be_successful

      expect(response.parsed_body["ai_personas"].length).to eq(AiPersona.count)
      expect(response.parsed_body["meta"]["commands"].length).to eq(
        DiscourseAi::AiBot::Personas::Persona.all_available_commands.length,
      )
    end

    it "returns commands options with each command" do
      persona1 = Fabricate(:ai_persona, name: "search1", commands: ["SearchCommand"])
      persona2 =
        Fabricate(
          :ai_persona,
          name: "search2",
          commands: [["SearchCommand", { base_query: "test" }]],
        )

      get "/admin/plugins/discourse-ai/ai_personas.json"
      expect(response).to be_successful

      serializer_persona1 = response.parsed_body["ai_personas"].find { |p| p["id"] == persona1.id }
      serializer_persona2 = response.parsed_body["ai_personas"].find { |p| p["id"] == persona2.id }

      commands = response.parsed_body["meta"]["commands"]
      search_command = commands.find { |c| c["id"] == "SearchCommand" }

      expect(search_command["help"]).to eq(I18n.t("discourse_ai.ai_bot.command_help.search"))

      expect(search_command["options"]).to eq(
        {
          "base_query" => {
            "type" => "string",
            "name" => I18n.t("discourse_ai.ai_bot.command_options.search.base_query.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.command_options.search.base_query.description"),
          },
          "max_results" => {
            "type" => "integer",
            "name" => I18n.t("discourse_ai.ai_bot.command_options.search.max_results.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.command_options.search.max_results.description"),
          },
        },
      )

      expect(serializer_persona1["commands"]).to eq(["SearchCommand"])
      expect(serializer_persona2["commands"]).to eq([["SearchCommand", { "base_query" => "test" }]])
    end

    it "returns localized persona names and descriptions" do
      SiteSetting.default_locale = "fr"

      get "/admin/plugins/discourse-ai/ai_personas.json"

      TranslationOverride.upsert!(:fr, "discourse_ai.ai_bot.personas.general.name", "Général")
      TranslationOverride.upsert!(
        :fr,
        "discourse_ai.ai_bot.personas.general.description",
        "Général Description",
      )

      id = DiscourseAi::AiBot::Personas.system_personas[DiscourseAi::AiBot::Personas::General]
      name = I18n.t("discourse_ai.ai_bot.personas.general.name")
      description = I18n.t("discourse_ai.ai_bot.personas.general.description")
      persona = response.parsed_body["ai_personas"].find { |p| p["id"] == id }

      expect(persona["name"]).to eq(name)
      expect(persona["description"]).to eq(description)
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai_personas/#{ai_persona.id}.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_persona"]["name"]).to eq(ai_persona.name)
    end
  end

  describe "POST #create" do
    context "with valid params" do
      let(:valid_attributes) do
        {
          name: "superbot",
          description: "Assists with tasks",
          system_prompt: "you are a helpful bot",
          commands: [["search", { "base_query" => "test" }]],
        }
      end

      it "creates a new AiPersona" do
        expect {
          post "/admin/plugins/discourse-ai/ai_personas.json",
               params: { ai_persona: valid_attributes }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
          expect(response).to be_successful
          persona = AiPersona.find(response.parsed_body["ai_persona"]["id"])
          expect(persona.commands).to eq([["search", { "base_query" => "test" }]])
        }.to change(AiPersona, :count).by(1)
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new ai_persona" do
        post "/admin/plugins/discourse-ai/ai_personas.json", params: { ai_persona: { foo: "" } } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      it "updates the requested ai_persona" do
        put "/admin/plugins/discourse-ai/ai_personas/#{ai_persona.id}.json",
            params: {
              ai_persona: {
                name: "SuperBot",
                enabled: false,
                commands: ["search"],
              },
            }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")

        ai_persona.reload
        expect(ai_persona.name).to eq("SuperBot")
        expect(ai_persona.enabled).to eq(false)
        expect(ai_persona.commands).to eq(["search"])
      end
    end

    context "with system personas" do
      it "does not allow editing of system prompts" do
        put "/admin/plugins/discourse-ai/ai_personas/#{DiscourseAi::AiBot::Personas.system_personas.values.first}.json",
            params: {
              ai_persona: {
                system_prompt: "you are not a helpful bot",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of commands" do
        put "/admin/plugins/discourse-ai/ai_personas/#{DiscourseAi::AiBot::Personas.system_personas.values.first}.json",
            params: {
              ai_persona: {
                commands: %w[SearchCommand ImageCommand],
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of name and description cause it is localized" do
        put "/admin/plugins/discourse-ai/ai_personas/#{DiscourseAi::AiBot::Personas.system_personas.values.first}.json",
            params: {
              ai_persona: {
                name: "bob",
                dscription: "the bob",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does allow some actions" do
        put "/admin/plugins/discourse-ai/ai_personas/#{DiscourseAi::AiBot::Personas.system_personas.values.first}.json",
            params: {
              ai_persona: {
                allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_1]],
                enabled: false,
                priority: 989,
              },
            }

        expect(response).to be_successful
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the ai_persona" do
        put "/admin/plugins/discourse-ai/ai_personas/#{ai_persona.id}.json",
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
        delete "/admin/plugins/discourse-ai/ai_personas/#{ai_persona.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(AiPersona, :count).by(-1)
    end

    it "is not allowed to delete system personas" do
      expect {
        delete "/admin/plugins/discourse-ai/ai_personas/#{DiscourseAi::AiBot::Personas.system_personas.values.first}.json"
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        # let's make sure this is translated
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      }.not_to change(AiPersona, :count)
    end
  end
end
