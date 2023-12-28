#frozen_string_literal: true

class TestPersona < DiscourseAi::AiBot::Personas::Persona
  def tools
    [
      DiscourseAi::AiBot::Tools::ListTags,
      DiscourseAi::AiBot::Tools::Search,
      DiscourseAi::AiBot::Tools::Image,
    ]
  end

  def system_prompt
    <<~PROMPT
      {site_url}
      {site_title}
      {site_description}
      {participants}
      {time}
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

    after do
      # we are rolling back transactions so we can create poison cache
      AiPersona.persona_cache.flush!
    end

    let(:context) do
      {
        site_url: Discourse.base_url,
        site_title: "test site title",
        site_description: "test site description",
        time: Time.zone.now,
        participants: topic_with_users.allowed_users.map(&:username).join(", "),
      }
    end

    fab!(:user)

    it "renders the system prompt" do
      freeze_time

      rendered = persona.craft_prompt(context)

      expect(rendered[:insts]).to include(Discourse.base_url)
      expect(rendered[:insts]).to include("test site title")
      expect(rendered[:insts]).to include("test site description")
      expect(rendered[:insts]).to include("joe, jane")
      expect(rendered[:insts]).to include(Time.zone.now.to_s)

      tools = rendered[:tools]

      expect(tools.find { |t| t[:name] == "search" }).to be_present
      expect(tools.find { |t| t[:name] == "tags" }).to be_present

      # needs to be configured so it is not available
      expect(tools.find { |t| t[:name] == "image" }).to be_nil
    end

    describe "custom personas" do
      it "is able to find custom personas" do
        Group.refresh_automatic_groups!

        # define an ai persona everyone can see
        persona =
          AiPersona.create!(
            name: "zzzpun_bot",
            description: "you write puns",
            system_prompt: "you are pun bot",
            commands: ["ImageCommand"],
            allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          )

        custom_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(custom_persona.name).to eq("zzzpun_bot")
        expect(custom_persona.description).to eq("you write puns")

        instance = custom_persona.new
        expect(instance.tools).to eq([DiscourseAi::AiBot::Tools::Image])
        expect(instance.craft_prompt(context).dig(:insts)).to eq("you are pun bot\n\n")

        # should update
        persona.update!(name: "zzzpun_bot2")
        custom_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(custom_persona.name).to eq("zzzpun_bot2")

        # can be disabled
        persona.update!(enabled: false)
        last_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(last_persona.name).not_to eq("zzzpun_bot2")

        persona.update!(enabled: true)
        # no groups have access
        persona.update!(allowed_group_ids: [])

        last_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(last_persona.name).not_to eq("zzzpun_bot2")
      end
    end

    describe "available personas" do
      it "includes all personas by default" do
        Group.refresh_automatic_groups!

        # must be enabled to see it
        SiteSetting.ai_stability_api_key = "abc"
        SiteSetting.ai_google_custom_search_api_key = "abc"
        SiteSetting.ai_google_custom_search_cx = "abc123"

        # should be ordered by priority and then alpha
        expect(DiscourseAi::AiBot::Personas.all(user: user)).to eq(
          [General, Artist, Creative, Researcher, SettingsExplorer, SqlHelper],
        )

        # omits personas if key is missing
        SiteSetting.ai_stability_api_key = ""
        SiteSetting.ai_google_custom_search_api_key = ""

        expect(DiscourseAi::AiBot::Personas.all(user: user)).to contain_exactly(
          General,
          SqlHelper,
          SettingsExplorer,
          Creative,
        )

        AiPersona.find(DiscourseAi::AiBot::Personas.system_personas[General]).update!(
          enabled: false,
        )

        expect(DiscourseAi::AiBot::Personas.all(user: user)).to contain_exactly(
          SqlHelper,
          SettingsExplorer,
          Creative,
        )
      end
    end
  end
end
