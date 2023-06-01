# frozen_string_literal: true

require_relative "../../../../support/anthropic_completion_stubs"

RSpec.describe DiscourseAi::Summarization::Strategies::Anthropic do
  describe "#summarize" do
    let(:model) { "claude-v1" }

    subject { described_class.new(model) }

    it "asks an Anthropic's model to summarize the content" do
      summarization_text = "This is a text"
      expected_response = "This is a summary"

      AnthropicCompletionStubs.stub_response(
        subject.prompt(summarization_text),
        "<ai>#{expected_response}</ai>",
        req_opts: {
          max_tokens_to_sample: 300,
        },
      )

      expect(subject.summarize(summarization_text)).to eq(expected_response)
    end
  end
end
