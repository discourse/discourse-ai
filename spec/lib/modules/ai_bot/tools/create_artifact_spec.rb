#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::CreateArtifact do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  fab!(:post)

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "correctly adds details block on final invoke" do
      tool =
        described_class.new(
          { html_body: "hello" },
          bot_user: Fabricate(:user),
          llm: llm,
          context: {
            post_id: post.id,
          },
        )

      tool.parameters = { html_body: "hello" }

      tool.invoke {}

      artifact_id = AiArtifact.order("id desc").limit(1).pluck(:id).first

      expected = <<~MD
        [details='View Source']

        ### HTML

        ```html
        hello
        ```

        [/details]

        ### Preview

        <div class="ai-artifact" data-ai-artifact-id="#{artifact_id}"></div>
      MD
      expect(tool.custom_raw.strip).to eq(expected.strip)
    end

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
