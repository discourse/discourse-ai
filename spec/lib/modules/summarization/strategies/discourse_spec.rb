# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::DiscourseAi do
  describe "#summarize" do
    let(:model) { "bart-large-cnn-samsum" }

    subject { described_class.new(model) }

    it "asks a Discourse's model to summarize the content" do
      SiteSetting.ai_summarization_discourse_service_api_endpoint = "https://test.com"
      summarization_text = "This is a text"
      expected_response = "This is a summary"

      WebMock
        .stub_request(
          :post,
          "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
        )
        .with(body: JSON.dump(model: model, content: subject.prompt(summarization_text)))
        .to_return(status: 200, body: JSON.dump(summary_text: expected_response))

      expect(subject.summarize(summarization_text)).to eq(expected_response)
    end
  end
end
