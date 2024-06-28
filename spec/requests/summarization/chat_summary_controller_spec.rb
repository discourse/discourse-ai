# frozen_string_literal: true

require_relative "../../support/dummy_custom_summarization"

RSpec.describe DiscourseAi::Summarization::ChatSummaryController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:group)
  let(:plugin) { Plugin::Instance.new }

  before do
    group.add(current_user)

    strategy = DummyCustomSummarization.new({ summary: "dummy", chunks: [] })
    SiteSetting.ai_summarization_strategy = strategy.model
    SiteSetting.ai_custom_summarization_allowed_groups = group.id

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = group.id
    sign_in(current_user)
  end

  after { DiscoursePluginRegistry.reset_register!(:summarization_strategies) }

  describe "#show" do
    context "when the user is not allowed to join the channel" do
      fab!(:channel) { Fabricate(:private_category_channel) }

      it "returns a 403" do
        get "/discourse-ai/summarization/channels/#{channel.id}", params: { since: 6 }

        expect(response.status).to eq(403)
      end
    end
  end
end
