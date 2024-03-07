# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::AiBot::Tools::GithubPullRequestDiff do
  let(:tool) { described_class.new({ repo: repo, pull_id: pull_id }) }
  let(:bot_user) { Fabricate(:user) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-4") }

  context "with a valid pull request" do
    let(:repo) { "discourse/discourse-automation" }
    let(:pull_id) { 253 }

    it "retrieves the diff for the pull request" do
      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/vnd.github.v3.diff",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: "sample diff")

      result = tool.invoke(bot_user, llm)
      expect(result[:diff]).to eq("sample diff")
      expect(result[:error]).to be_nil
    end

    it "uses the github access token if present" do
      SiteSetting.ai_bot_github_access_token = "ABC"

      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/vnd.github.v3.diff",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: "sample diff")

      result = tool.invoke(bot_user, llm)
      expect(result[:diff]).to eq("sample diff")
      expect(result[:error]).to be_nil
    end
  end

  context "with an invalid pull request" do
    let(:repo) { "invalid/repo" }
    let(:pull_id) { 999 }

    it "returns an error message" do
      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/vnd.github.v3.diff",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 404)

      result = tool.invoke(bot_user, nil)
      expect(result[:diff]).to be_nil
      expect(result[:error]).to include("Failed to retrieve the diff")
    end
  end
end
