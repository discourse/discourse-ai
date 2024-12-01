# spec/lib/modules/ai_bot/tools/update_artifact_spec.rb
# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::UpdateArtifact do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  fab!(:post)
  fab!(:artifact) do
    AiArtifact.create!(
      user: Fabricate(:user),
      post: post,
      name: "Test Artifact",
      html: "<div>\nOriginal\n</div>",
      css: "div {\n color: blue; \n}",
      js: "console.log('hello');",
    )
  end

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    let(:html) { <<~DIFF }
         <div>
           Updated
         </div>
      DIFF

    let(:css) { <<~DIFF }
         div {
          color: red;
         }
      DIFF

    let(:js) { <<~DIFF }
        console.log('world');
      DIFF

    it "updates artifact content when supplied" do
      tool =
        described_class.new(
          {
            artifact_id: artifact.id,
            html: html,
            css: css,
            js: js,
            change_description: "Updated colors and text",
          },
          bot_user: bot_user,
          llm: llm,
          context: {
            post_id: post.id,
          },
        )

      result = tool.invoke {}

      expect(result[:status]).to eq("success")
      expect(result[:version]).to eq(1)

      version = artifact.versions.find_by(version_number: 1)
      expect(version.html).to include("Updated")
      expect(version.css).to include("color: red")
      expect(version.js).to include("'world'")
      expect(artifact.versions.count).to eq(1)
      expect(version.change_description).to eq("Updated colors and text")
    end

    it "handles partial updates correctly" do
      tool = described_class.new({}, bot_user: bot_user, llm: llm)

      tool.parameters = { artifact_id: artifact.id, html: html, change_description: "Changed HTML" }
      tool.partial_invoke

      expect(tool.custom_raw).to include("### HTML Changes")
      expect(tool.custom_raw).to include("### Change Description")
      expect(tool.custom_raw).not_to include("### CSS Changes")
    end

    it "handles invalid artifact ID" do
      tool =
        described_class.new(
          { artifact_id: -1, html: html, change_description: "Test change" },
          bot_user: bot_user,
          llm: llm,
          context: {
            post_id: post.id,
          },
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("error")
      expect(result[:error]).to eq("Artifact not found")
    end

    it "requires at least one change" do
      tool =
        described_class.new(
          { artifact_id: artifact.id, change_description: "No changes" },
          bot_user: bot_user,
          llm: llm,
          context: {
            post_id: post.id,
          },
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")
      expect(artifact.versions.count).to eq(1)
    end

    it "correctly renders changes in message" do
      tool =
        described_class.new(
          { artifact_id: artifact.id, html: html, change_description: "Updated content" },
          bot_user: bot_user,
          llm: llm,
          context: {
            post_id: post.id,
          },
        )

      tool.invoke {}

      expect(tool.custom_raw.strip).to include(html.strip)
    end
  end
end
