# frozen_string_literal: true

require_relative "vector_rep_shared_examples"

RSpec.describe DiscourseAi::Embeddings::VectorRepresentations::Gemini do
  subject(:vector_rep) { described_class.new(truncation) }

  let(:truncation) { DiscourseAi::Embeddings::Strategies::Truncation.new }
  let!(:api_key) { "test-123" }

  before { SiteSetting.ai_gemini_api_key = api_key }

  def stub_vector_mapping(text, expected_embedding)
    EmbeddingsGenerationStubs.gemini_service(api_key, text, expected_embedding)
  end

  it_behaves_like "generates and store embedding using with vector representation"
end
