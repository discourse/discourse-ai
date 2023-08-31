#frozen_string_literal: true

class TestPersona < DiscourseAi::AiBot::Personas::Persona
  def commands
    [
      DiscourseAi::AiBot::Commands::TagsCommand,
      DiscourseAi::AiBot::Commands::SearchCommand,
      DiscourseAi::AiBot::Commands::ImageCommand,
    ]
  end

  def system_prompt
    <<~PROMPT
      {site_url}
      {site_title}
      {site_description}
      {participants}
      {time}

      {commands}
    PROMPT
  end
end

module DiscourseAi::AiBot::Personas
  RSpec.describe Persona do
    let :persona do
      TestPersona.new
    end

    let :topic_with_users do
      topic = Topic.new
      topic.allowed_users = [User.new(username: "joe"), User.new(username: "jane")]
      topic
    end

    it "renders the system prompt" do
      freeze_time

      SiteSetting.title = "test site title"
      SiteSetting.site_description = "test site description"

      rendered =
        persona.render_system_prompt(topic: topic_with_users, render_function_instructions: true)

      expect(rendered).to include(Discourse.base_url)
      expect(rendered).to include("test site title")
      expect(rendered).to include("test site description")
      expect(rendered).to include("joe, jane")
      expect(rendered).to include(Time.zone.now.to_s)
      expect(rendered).to include("!search")
      expect(rendered).to include("!tags")
      # needs to be configured so it is not available
      expect(rendered).not_to include("!image")

      rendered =
        persona.render_system_prompt(topic: topic_with_users, render_function_instructions: false)

      expect(rendered).not_to include("!search")
      expect(rendered).not_to include("!tags")
    end

    describe "available personas" do
      it "includes all personas by default" do
        # must be enabled to see it
        SiteSetting.ai_stability_api_key = "abc"

        expect(DiscourseAi::AiBot::Personas.all).to contain_exactly(
          General,
          SqlHelper,
          Artist,
          SettingsExplorer,
        )
      end

      it "can be modified via site settings" do
        SiteSetting.ai_bot_enabled_personas = "general|sql_helper"

        expect(DiscourseAi::AiBot::Personas.all).to contain_exactly(General, SqlHelper)
      end
    end
  end
end
