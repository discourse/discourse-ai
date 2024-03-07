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

RSpec.describe DiscourseAi::AiBot::Personas::Persona do
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
    system_message = rendered.messages.first[:content]

    expect(system_message).to include(Discourse.base_url)
    expect(system_message).to include("test site title")
    expect(system_message).to include("test site description")
    expect(system_message).to include("joe, jane")
    expect(system_message).to include(Time.zone.now.to_s)

    tools = rendered.tools

    expect(tools.find { |t| t[:name] == "search" }).to be_present
    expect(tools.find { |t| t[:name] == "tags" }).to be_present

    # needs to be configured so it is not available
    expect(tools.find { |t| t[:name] == "image" }).to be_nil
  end

  it "can correctly parse arrays in tools" do
    SiteSetting.ai_openai_api_key = "123"

    # Dall E tool uses an array for params
    xml = <<~XML
      <function_calls>
        <invoke>
        <tool_name>dall_e</tool_name>
        <tool_id>call_JtYQMful5QKqw97XFsHzPweB</tool_id>
        <parameters>
        <prompts>["cat oil painting", "big car"]</prompts>
        </parameters>
        </invoke>
        <invoke>
        <tool_name>dall_e</tool_name>
        <tool_id>abc</tool_id>
        <parameters>
        <prompts>["pic3"]</prompts>
        </parameters>
        </invoke>
      </function_calls>
    XML
    dall_e1, dall_e2 = DiscourseAi::AiBot::Personas::DallE3.new.find_tools(xml)
    expect(dall_e1.parameters[:prompts]).to eq(["cat oil painting", "big car"])
    expect(dall_e2.parameters[:prompts]).to eq(["pic3"])
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

      custom_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
      expect(custom_persona.name).to eq("zzzpun_bot")
      expect(custom_persona.description).to eq("you write puns")

      instance = custom_persona.new
      expect(instance.tools).to eq([DiscourseAi::AiBot::Tools::Image])
      expect(instance.craft_prompt(context).messages.first[:content]).to eq("you are pun bot")

      # should update
      persona.update!(name: "zzzpun_bot2")
      custom_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
      expect(custom_persona.name).to eq("zzzpun_bot2")

      # can be disabled
      persona.update!(enabled: false)
      last_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
      expect(last_persona.name).not_to eq("zzzpun_bot2")

      persona.update!(enabled: true)
      # no groups have access
      persona.update!(allowed_group_ids: [])

      last_persona = DiscourseAi::AiBot::Personas::Persona.all(user: user).last
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
      expect(DiscourseAi::AiBot::Personas::Persona.all(user: user)).to eq(
        [
          DiscourseAi::AiBot::Personas::General,
          DiscourseAi::AiBot::Personas::Artist,
          DiscourseAi::AiBot::Personas::Creative,
          DiscourseAi::AiBot::Personas::DiscourseHelper,
          DiscourseAi::AiBot::Personas::GithubHelper,
          DiscourseAi::AiBot::Personas::Researcher,
          DiscourseAi::AiBot::Personas::SettingsExplorer,
          DiscourseAi::AiBot::Personas::SqlHelper,
        ],
      )

      # omits personas if key is missing
      SiteSetting.ai_stability_api_key = ""
      SiteSetting.ai_google_custom_search_api_key = ""

      expect(DiscourseAi::AiBot::Personas::Persona.all(user: user)).to contain_exactly(
        DiscourseAi::AiBot::Personas::General,
        DiscourseAi::AiBot::Personas::SqlHelper,
        DiscourseAi::AiBot::Personas::SettingsExplorer,
        DiscourseAi::AiBot::Personas::Creative,
        DiscourseAi::AiBot::Personas::DiscourseHelper,
        DiscourseAi::AiBot::Personas::GithubHelper,
      )

      AiPersona.find(
        DiscourseAi::AiBot::Personas::Persona.system_personas[
          DiscourseAi::AiBot::Personas::General
        ],
      ).update!(enabled: false)

      expect(DiscourseAi::AiBot::Personas::Persona.all(user: user)).to contain_exactly(
        DiscourseAi::AiBot::Personas::SqlHelper,
        DiscourseAi::AiBot::Personas::SettingsExplorer,
        DiscourseAi::AiBot::Personas::Creative,
        DiscourseAi::AiBot::Personas::DiscourseHelper,
        DiscourseAi::AiBot::Personas::GithubHelper,
      )
    end
  end
end
