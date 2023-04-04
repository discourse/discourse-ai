# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::SummaryController do
  describe "#chat_channel" do
    describe "validating inputs" do
      it "returns a 404 if there is no chat channel" do
        post "/disoucrse-ai/summarization/chat-channel", params: { chat_channel_id: 99, since: 3 }

        expect(response.status).to eq(404)
      end

      it "returns a 400 if the since param is invalid" do
        chat_channel = Fabricate(:chat_channel)

        post "/disoucrse-ai/summarization/chat-channel",
             params: {
               chat_channel_id: chat_channel.id,
               since: 0,
             }

        expect(response.status).to eq(404)
      end
    end
  end
end
