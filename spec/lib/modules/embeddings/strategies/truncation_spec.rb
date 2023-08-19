# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::Strategies::Truncation do
  describe "#process!" do
    context "when the model uses OpenAI to create embeddings" do
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

      let(:model) { DiscourseAi::Embeddings::Models::Base.descendants.sample(1).first }
      let(:truncation) { described_class.new(topic, model) }

      it "truncates a topic" do
        truncation.process!

        expect(model.tokenizer.size(truncation.processed_target)).to be <= model.max_sequence_length
      end
    end
  end
end
