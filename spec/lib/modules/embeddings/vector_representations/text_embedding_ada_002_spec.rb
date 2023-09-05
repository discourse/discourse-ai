# frozen_string_literal: true

require_relative "../../../../support/embeddings_generation_stubs"
require_relative "vector_rep_shared_examples"

RSpec.describe DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002 do
  subject(:vector_rep) { described_class.new(truncation) }

  let(:truncation) { DiscourseAi::Embeddings::Strategies::Truncation.new }

  def stub_vector_mapping(text, expected_embedding)
    EmbeddingsGenerationStubs.openai_service(vector_rep.name, text, expected_embedding)
  end

  it_behaves_like "generates and store embedding using with vector representation"
end
