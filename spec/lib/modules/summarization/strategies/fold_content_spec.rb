# frozen_string_literal: true

require_relative "../../../../support/summarization/dummy_completion_model"

RSpec.describe DiscourseAi::Summarization::Strategies::FoldContent do
  describe "#summarize" do
    subject(:strategy) { described_class.new(model) }

    let(:summarize_text) { "This is a text" }
    let(:model) { DummyCompletionModel.new(model_tokens) }
    let(:model_tokens) do
      # Make sure each content fits in a single chunk.
      DiscourseAi::Tokenizer::BertTokenizer.size("(1 asd said: This is a text ") + 3
    end

    let(:content) { { contents: [{ poster: "asd", id: 1, text: summarize_text }] } }

    context "when the content to summarize fits in a single call" do
      it "does one call to summarize content" do
        result = strategy.summarize(content)

        expect(model.summarization_calls).to eq(1)
        expect(result[:summary]).to eq(DummyCompletionModel::SINGLE_SUMMARY)
      end
    end

    context "when the content to summarize doesn't fit in a single call" do
      it "summarizes each chunk and then concatenates them" do
        content[:contents] << { poster: "asd2", id: 2, text: summarize_text }

        result = strategy.summarize(content)

        expect(model.summarization_calls).to eq(3)
        expect(result[:summary]).to eq(DummyCompletionModel::CONCATENATED_SUMMARIES)
      end
    end
  end
end
