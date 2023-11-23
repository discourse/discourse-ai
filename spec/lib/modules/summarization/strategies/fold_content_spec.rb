# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::FoldContent do
  describe "#summarize" do
    subject(:strategy) { described_class.new(model) }

    let(:summarize_text) { "This is a text" }
    let(:model_tokens) do
      # Make sure each content fits in a single chunk.
      # 700 is the number of tokens reserved for the prompt.
      700 + DiscourseAi::Tokenizer::OpenAiTokenizer.size("(1 asd said: This is a text ") + 3
    end

    let(:model) do
      DiscourseAi::Summarization::Models::OpenAi.new("gpt-4", max_tokens: model_tokens)
    end

    let(:content) { { contents: [{ poster: "asd", id: 1, text: summarize_text }] } }

    let(:single_summary) { "this is a single summary" }
    let(:concatenated_summary) { "this is a concatenated summary" }

    let(:user) { User.new }

    context "when the content to summarize fits in a single call" do
      it "does one call to summarize content" do
        result =
          DiscourseAi::Completions::LLM.with_prepared_responses([single_summary]) do |spy|
            strategy.summarize(content, user).tap { expect(spy.completions).to eq(1) }
          end

        expect(result[:summary]).to eq(single_summary)
      end
    end

    context "when the content to summarize doesn't fit in a single call" do
      it "summarizes each chunk and then concatenates them" do
        content[:contents] << { poster: "asd2", id: 2, text: summarize_text }

        result =
          DiscourseAi::Completions::LLM.with_prepared_responses(
            [single_summary, single_summary, concatenated_summary],
          ) { |spy| strategy.summarize(content, user).tap { expect(spy.completions).to eq(3) } }

        expect(result[:summary]).to eq(concatenated_summary)
      end
    end
  end
end
