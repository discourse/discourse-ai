# frozen_string_literal: true

def has_rg?
  if defined?(@has_rg)
    @has_rg
  else
    @has_rg |= system("which rg")
  end
end

  describe "#execute" do
    before do
      skip("rg is needed for these tests") if !has_rg?
    end

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
        skip("rg is needed for these tests") if !has_rg?
        result = command.process(setting_name: "this_setting_does_not_exist")
        expect(result[:context]).to eq("This setting does not exist")
      end
    end
  end

  def has_rg?
    if defined?(@has_rg)
      @has_rg
    else
      @has_rg |= system("which rg")
    end
  end
end
