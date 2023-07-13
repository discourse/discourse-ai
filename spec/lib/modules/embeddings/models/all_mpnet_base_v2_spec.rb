# frozen_string_literal: true

require_relative "../../../../support/embeddings_generation_stubs"

RSpec.describe DiscourseAi::Embeddings::Models::AllMpnetBaseV2 do
  describe "#generate_embeddings" do
    let(:input) { "test" }
    let(:expected_embedding) { [0.0038493, 0.482001] }

    context "when the model uses the discourse service to create embeddings" do
      before { SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com" }

      let(:discourse_model) { "all-mpnet-base-v2" }

      it "returns an embedding for a given string" do
        EmbeddingsGenerationStubs.discourse_service(discourse_model, input, expected_embedding)

        embedding = described_class.generate_embeddings(input)

        expect(embedding).to contain_exactly(*expected_embedding)
      end
    end
  end
end
