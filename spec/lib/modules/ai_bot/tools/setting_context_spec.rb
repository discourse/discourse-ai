# frozen_string_literal: true

def has_rg?
  if defined?(@has_rg)
    @has_rg
  else
    @has_rg |= system("which rg")
  end
end

RSpec.describe DiscourseAi::AiBot::Tools::SettingContext, if: has_rg? do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("gpt-3.5-turbo") }

  before { SiteSetting.ai_bot_enabled = true }

  def setting_context(setting_name)
    described_class.new({ setting_name: setting_name })
  end

  describe "#execute" do
    it "returns the context for core setting" do
      result = setting_context("moderators_view_emails").invoke(bot_user, llm)

      expect(result[:setting_name]).to eq("moderators_view_emails")

      expect(result[:context]).to include("site_settings.yml")
      expect(result[:context]).to include("moderators_view_emails")
    end

    it "returns the context for plugin setting" do
      result = setting_context("ai_bot_enabled").invoke(bot_user, llm)

      expect(result[:setting_name]).to eq("ai_bot_enabled")
      expect(result[:context]).to include("ai_bot_enabled:")
    end

    context "when the setting does not exist" do
      it "returns an error message" do
        result = setting_context("this_setting_does_not_exist").invoke(bot_user, llm)

        expect(result[:context]).to eq("This setting does not exist")
      end
    end
  end
end
