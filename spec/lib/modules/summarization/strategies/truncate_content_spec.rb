# frozen_string_literal: true

require_relative "../../../../support/summarization/dummy_completion_model"

RSpec.describe DiscourseAi::Summarization::Strategies::TruncateContent do
  describe "#summarize" do
    let(:summarize_text) { "This is a text" }
    let(:model_tokens) { summarize_text.length }
    let(:model) { DummyCompletionModel.new(model_tokens) }

    subject { described_class.new(model) }

    let(:content) { { contents: [{ poster: "asd", id: 1, text: summarize_text }] } }

    context "when the content to summarize doesn't fit in a single call" do
      it "summarizes a truncated version" do
        content[:contents] << { poster: "asd2", id: 2, text: summarize_text }

        result = subject.summarize(content)

        expect(model.summarization_calls).to eq(1)
        expect(result[:summary]).to eq(DummyCompletionModel::SINGLE_SUMMARY)
      end
    end
  end
end
