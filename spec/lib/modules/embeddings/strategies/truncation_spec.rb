# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::Strategies::Truncation do
  subject(:truncation) { described_class.new }

  describe "#prepare_query_text" do
    context "when using vector def from OpenAI" do
      before { SiteSetting.max_post_length = 100_000 }

      fab!(:topic)
      fab!(:post) do
        Fabricate(:post, topic: topic, raw: "Baby, bird, bird, bird\nBird is the word\n" * 500)
      end
      fab!(:post) do
        Fabricate(
          :post,
          topic: topic,
          raw: "Don't you know about the bird?\nEverybody knows that the bird is a word\n" * 400,
        )
      end
      fab!(:post) { Fabricate(:post, topic: topic, raw: "Surfin' bird\n" * 800) }
      fab!(:open_ai_embedding_def)

      it "truncates a topic" do
        prepared_text = truncation.prepare_target_text(topic, open_ai_embedding_def)

        expect(open_ai_embedding_def.tokenizer.size(prepared_text)).to be <=
          open_ai_embedding_def.max_sequence_length
      end
    end
  end
end
