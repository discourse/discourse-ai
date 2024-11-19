RSpec.describe DiscourseAi::AiBot::ArtifactsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:private_message_topic, user: user) }
  fab!(:post) { Fabricate(:post, user: user, topic: topic) }
  fab!(:artifact) do
    AiArtifact.create!(
      user: user,
      post: post,
      name: "Test Artifact",
      html: "<div>Hello World</div>",
      css: "div { color: blue; }",
      js: "console.log('test');",
      metadata: {
        public: false,
      },
    )
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_artifact_security = "strict"
  end

  describe "#show" do
    it "returns 404 when discourse_ai is disabled" do
      SiteSetting.discourse_ai_enabled = false
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.status).to eq(404)
    end

    it "returns 404 when ai_artifact_security disables it" do
      SiteSetting.ai_artifact_security = "disabled"
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.status).to eq(404)
    end

    context "with private artifact" do
      it "returns 404 when user cannot see the post" do
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(404)
      end

      it "shows artifact when user can see the post" do
        sign_in(user)
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(200)
        expect(response.body).to include(artifact.html)
        expect(response.body).to include(artifact.css)
        expect(response.body).to include(artifact.js)
      end
    end

    context "with public artifact" do
      before { artifact.update!(metadata: { public: true }) }

      it "shows artifact without authentication" do
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(200)
        expect(response.body).to include(artifact.html)
      end
    end

    it "removes security headers" do
      sign_in(user)
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.headers["X-Frame-Options"]).to eq(nil)
      expect(response.headers["Content-Security-Policy"]).to eq("script-src 'unsafe-inline';")
    end
  end
end
