# frozen_string_literal: true

require_relative "vector_rep_shared_examples"

RSpec.describe DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2 do
  subject(:vector_rep) { described_class.new(truncation) }

  let(:truncation) { DiscourseAi::Embeddings::Strategies::Truncation.new }

  before { SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com" }

  def stub_vector_mapping(text, expected_embedding)
    EmbeddingsGenerationStubs.discourse_service(described_class.name, text, expected_embedding)
  end

  it_behaves_like "generates and store embedding using with vector representation"
end
