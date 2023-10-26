# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::Strategies::Truncation do
  subject(:truncation) { described_class.new }

  describe "#prepare_text_from" do
    context "when using vector from OpenAI" do
      before { SiteSetting.max_post_length = 100_000 }

      fab!(:topic) { Fabricate(:topic) }
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

      let(:model) do
        DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002.new(truncation)
      end

      it "truncates a topic" do
        prepared_text =
          truncation.prepare_text_from(topic, model.tokenizer, model.max_sequence_length)

        expect(model.tokenizer.size(prepared_text)).to be <= model.max_sequence_length
      end

      it "doesn't try to append category information if there isn't one" do
        pm = Fabricate(:private_message_topic)

        prepared_text = truncation.prepare_text_from(pm, model.tokenizer, model.max_sequence_length)

        expect(model.tokenizer.size(prepared_text)).to be <= model.max_sequence_length
      end
    end
  end
end
