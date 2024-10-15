# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::FoldContent do
  subject(:summarizer) { DiscourseAi::Summarization.topic_summary(topic) }

  describe "#summarize" do
    let!(:llm_model) { assign_fake_provider_to(:ai_summarization_model) }

    fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
    fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1, raw: "This is a text") }

    before do
      SiteSetting.ai_summarization_enabled = true

      # Make sure each content fits in a single chunk.
      # 700 is the number of tokens reserved for the prompt.
      model_tokens =
        700 + DiscourseAi::Tokenizer::OpenAiTokenizer.size("(1 asd said: This is a text ") + 3

      llm_model.update!(max_prompt_tokens: model_tokens)
    end

    let(:single_summary) { "this is a single summary" }
    let(:concatenated_summary) { "this is a concatenated summary" }

    let(:user) { User.new }

    context "when the content to summarize fits in a single call" do
      it "does one call to summarize content" do
        result =
          DiscourseAi::Completions::Llm.with_prepared_responses([single_summary]) do |spy|
            summarizer.summarize(user).tap { expect(spy.completions).to eq(1) }
          end

        expect(result.summarized_text).to eq(single_summary)
      end
    end

    context "when the content to summarize doesn't fit in a single call" do
      fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2, raw: "This is a text") }

      it "summarizes each chunk and then concatenates them" do
        result =
          DiscourseAi::Completions::Llm.with_prepared_responses(
            [single_summary, single_summary, concatenated_summary],
          ) { |spy| summarizer.summarize(user).tap { expect(spy.completions).to eq(3) } }

        expect(result.summarized_text).to eq(concatenated_summary)
      end

      it "keeps splitting into chunks until the content fits into a single call to create a cohesive narrative" do
        max_length_response = "(1 asd said: This is a text "
        chunk_of_chunks = "I'm smol"

        result =
          DiscourseAi::Completions::Llm.with_prepared_responses(
            [
              max_length_response,
              max_length_response,
              chunk_of_chunks,
              chunk_of_chunks,
              concatenated_summary,
            ],
          ) { |spy| summarizer.summarize(user).tap { expect(spy.completions).to eq(5) } }

        expect(result.summarized_text).to eq(concatenated_summary)
      end
    end
  end
end
