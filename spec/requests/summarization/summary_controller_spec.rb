# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::SummaryController do
  describe "#chat_channel" do
    fab!(:user) { Fabricate(:user) }
    let!(:channel_group) { Fabricate(:group) }
    let!(:chat_channel) { Fabricate(:private_category_channel, group: channel_group) }

    before do
      SiteSetting.ai_summarization_enabled = true
      sign_in(user)
    end

    context "when the user can see the channel" do
      before { channel_group.add(user) }

      describe "validating inputs" do
        it "returns a 404 if there is no chat channel" do
          post "/discourse-ai/summarization/chat-channel", params: { chat_channel_id: 99, since: 3 }

          expect(response.status).to eq(404)
        end

        it "returns a 400 if the since param is invalid" do
          post "/discourse-ai/summarization/chat-channel",
               params: {
                 chat_channel_id: chat_channel.id,
                 since: 0,
               }

          expect(response.status).to eq(400)
        end

        it "returns a 404 when the module is disabled" do
          SiteSetting.ai_summarization_enabled = false

          post "/discourse-ai/summarization/chat-channel",
               params: {
                 chat_channel_id: chat_channel.id,
                 since: 1,
               }

          expect(response.status).to eq(404)
        end
      end

      context "when the user can't see the channel" do
        before { channel_group.remove(user) }

        it "returns a 403 if the user can't see the chat channel" do
          post "/discourse-ai/summarization/chat-channel",
               params: {
                 chat_channel_id: chat_channel.id,
                 since: 1,
               }

          expect(response.status).to eq(403)
        end
      end
    end
  end
end
