# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Models::Discourse do
  let(:model) { "bart-large-cnn-samsum" }
  let(:max_tokens) { 20 }

  subject { described_class.new(model, max_tokens: max_tokens) }

  let(:content) do
    {
      resource_path: "/t/1/POST_NUMBER",
      content_title: "This is a title",
      contents: [{ poster: "asd", id: 1, text: "This is a text" }],
    }
  end

  before { SiteSetting.ai_summarization_discourse_service_api_endpoint = "https://test.com" }

  def stub_request(prompt, response)
    WebMock
      .stub_request(
        :post,
        "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
      )
      .with(body: JSON.dump(model: model, content: prompt))
      .to_return(status: 200, body: JSON.dump(summary_text: response))
  end

  def expected_messages(contents, opts)
    contents.reduce("") do |memo, item|
      memo += "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
    end
  end

  describe "#summarize_in_chunks" do
    context "when the content fits in a single chunk" do
      it "performs a request to summarize" do
        opts = content.except(:contents)

        stub_request(expected_messages(content[:contents], opts), "This is summary 1")

        expect(subject.summarize_in_chunks(content[:contents], opts)).to contain_exactly(
          "This is summary 1",
        )
      end
    end

    context "when the content fits in multiple chunks" do
      it "performs a request for each one to summarize" do
        content[:contents] << {
          poster: "asd2",
          id: 2,
          text: "This is a different text to summarize",
        }
        opts = content.except(:contents)

        content[:contents].each_with_index do |item, idx|
          stub_request(expected_messages([item], opts), "This is summary #{idx + 1}")
        end

        expect(subject.summarize_in_chunks(content[:contents], opts)).to contain_exactly(
          "This is summary 1",
          "This is summary 2",
        )
      end
    end
  end

  describe "#concatenate_summaries" do
    it "combines all the different summaries into a single one" do
      messages = ["summary 1", "summary 2"].join("\n")

      stub_request(messages, "concatenated summary")

      expect(subject.concatenate_summaries(["summary 1", "summary 2"])).to eq(
        "concatenated summary",
      )
    end
  end

  describe "#summarize_with_truncation" do
    let(:max_tokens) { 9 }

    it "truncates the context to meet the token limit" do
      opts = content.except(:contents)

      stub_request("( 1 asd said : this is", "truncated summary")

      expect(subject.summarize_with_truncation(content[:contents], opts)).to eq("truncated summary")
    end
  end
end
