# frozen_string_literal: true

require_relative "../../../../support/embeddings_generation_stubs"

RSpec.describe DiscourseAi::Embeddings::Models::TextEmbeddingAda002 do
  describe "#generate_embeddings" do
    let(:input) { "test" }
    let(:expected_embedding) { [0.0038493, 0.482001] }

    context "when the model uses OpenAI to create embeddings" do
      let(:openai_model) { "text-embedding-ada-002" }

      it "returns an embedding for a given string" do
        EmbeddingsGenerationStubs.openai_service(openai_model, input, expected_embedding)

        embedding = described_class.generate_embeddings(input)

        expect(embedding).to contain_exactly(*expected_embedding)
      end
    end
  end
end
