# frozen_string_literal: true

require_relative "../../../support/embeddings_generation_stubs"

RSpec.describe DiscourseAi::Embeddings::Model do
  describe "#generate_embedding" do
    let(:input) { "test" }
    let(:expected_embedding) { [0.0038493, 0.482001] }

    context "when the model uses the discourse service to create embeddings" do
      before { SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com" }

      let(:discourse_model) { "all-mpnet-base-v2" }

      it "returns an embedding for a given string" do
        EmbeddingsGenerationStubs.discourse_service(discourse_model, input, expected_embedding)

        embedding = described_class.instantiate(discourse_model).generate_embedding(input)

        expect(embedding).to contain_exactly(*expected_embedding)
      end
    end

    context "when the model uses OpenAI to create embeddings" do
      let(:openai_model) { "text-embedding-ada-002" }

      it "returns an embedding for a given string" do
        EmbeddingsGenerationStubs.openai_service(openai_model, input, expected_embedding)

        embedding = described_class.instantiate(openai_model).generate_embedding(input)

        expect(embedding).to contain_exactly(*expected_embedding)
      end
    end
  end
end
