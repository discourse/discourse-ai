#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::CreateArtifact do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "can correctly handle partial updates" do
      tool = described_class.new({}, bot_user: bot_user, llm: llm)

      tool.parameters = { css: "a { }" }
      tool.partial_invoke

      expect(tool.custom_raw).to eq("### CSS\n\n```css\na { }\n```")

      tool.parameters = { css: "a { }", html_body: "hello" }
      tool.partial_invoke

      expect(tool.custom_raw).to eq(
        "### CSS\n\n```css\na { }\n```\n\n### HTML\n\n```html\nhello\n```",
      )

      tool.parameters = { css: "a { }", html_body: "hello world" }
      tool.partial_invoke

      expect(tool.custom_raw).to eq(
        "### CSS\n\n```css\na { }\n```\n\n### HTML\n\n```html\nhello world\n```",
      )
    end
  end
end
