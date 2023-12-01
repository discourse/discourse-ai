# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::TruncateContent do
  subject(:strategy) { described_class.new(model) }

  before { SiteSetting.ai_summarization_discourse_service_api_endpoint = "https://test.com" }

  let(:summarize_text) { "This is a text" }
  let(:full_text) { "(1 asd said: #{summarize_text} " }
  let(:model_tokens) { ::DiscourseAi::Tokenizer::BertTokenizer.size(full_text) - 5 }

  let(:model) do
    DiscourseAi::Summarization::Models::Discourse.new(
      "flan-t5-base-samsum",
      max_tokens: model_tokens,
    )
  end

  let(:content) { { contents: [{ poster: "asd", id: 1, text: summarize_text }] } }

  let(:summarized_text) { "this is a single summary" }

  let(:user) { User.new }

  describe "#summary" do
    it "truncates the content and requests a summary" do
      truncated =
        ::DiscourseAi::Tokenizer::BertTokenizer.truncate(
          "(1 asd said: This is a text ",
          model_tokens,
        )

      WebMock
        .stub_request(
          :post,
          "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
        )
        .with(body: JSON.dump(model: model.model, content: truncated))
        .to_return(status: 200, body: JSON.dump({ summary_text: summarized_text }))

      summary = strategy.summarize(content, user).dig(:summary)

      expect(summary).to eq(summarized_text)
    end
  end
end
