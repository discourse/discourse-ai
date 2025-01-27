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
      html: "<div>Original</div>",
      css: ".test { color: blue; }",
      js: "console.log('original');\nconsole.log('world');\nconsole.log('hello');",
    )
  end

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "correctly updates artifact using search/replace markers" do
      responses = [<<~TXT.strip]
        --- HTML ---
        <<<<<<< SEARCH
        <div>Original</div>
        =======
        <div>Updated</div>
        >>>>>>> REPLACE
        --- CSS ---
        <<<<<<< SEARCH
        .test { color: blue; }
        =======
        .test { color: red; }
        >>>>>>> REPLACE
        --- JavaScript ---
        <<<<<<< SEARCH
        console.log('original');
        =======
        console.log('updated');
        >>>>>>> REPLACE
        <<<<<<< SEARCH
        console.log('hello');
        =======
        console.log('updated2');
        >>>>>>> REPLACE
      TXT

      tool = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            {
              artifact_id: artifact.id,
              instructions: "Change the text to Updated and color to red",
            },
            bot_user: bot_user,
            llm: llm,
            context: {
              post_id: post.id,
            },
          )

        result = tool.invoke {}
        expect(result[:status]).to eq("success")
      end

      version = artifact.versions.last
      expect(version.html).to eq("<div>Updated</div>")
      expect(version.css).to eq(".test { color: red; }")
      expect(version.js).to eq(<<~JS.strip)
        console.log('updated');
        console.log('world');
        console.log('updated2');
      JS

      expect(tool.custom_raw).to include("### Change Description")
      expect(tool.custom_raw).to include("[details='View Changes']")
      expect(tool.custom_raw).to include("### HTML Changes")
      expect(tool.custom_raw).to include("### CSS Changes")
      expect(tool.custom_raw).to include("### JS Changes")
      expect(tool.custom_raw).to include("<div class=\"ai-artifact\"")
    end

    it "handles invalid search/replace format" do
      responses = ["--- HTML ---\nInvalid format without markers"]

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            { artifact_id: artifact.id, instructions: "Invalid update" },
            bot_user: bot_user,
            llm: llm,
            context: {
              post_id: post.id,
            },
          )

        result = tool.invoke {}
        expect(result[:status]).to eq("error")
        expect(result[:error]).to eq("Invalid format in html section")
      end
    end

    it "handles invalid artifact ID" do
      tool =
        described_class.new(
          { artifact_id: -1, instructions: "Update something" },
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

    it "only includes sections with changes" do
      responses = [<<~TXT.strip]
        --- HTML ---
        <<<<<<< SEARCH
        <div>Original</div>
        =======
        <div>Updated</div>
        >>>>>>> REPLACE
      TXT

      tool = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            { artifact_id: artifact.id, instructions: "Just update the HTML" },
            bot_user: bot_user,
            llm: llm,
            context: {
              post_id: post.id,
            },
          )

        tool.invoke {}
      end

      expect(tool.custom_raw).to include("### HTML Changes")
      expect(tool.custom_raw).not_to include("### CSS Changes")
      expect(tool.custom_raw).not_to include("### JavaScript Changes")
    end
  end
end
