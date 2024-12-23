# frozen_string_literal: true

require_relative "../support/embeddings_generation_stubs"

RSpec.describe DiscourseAi::Configuration::EmbeddingsModelValidator do
  before { SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com" }

  describe "#can_generate_embeddings?" do
    it "works" do
      discourse_model = "all-mpnet-base-v2"

      EmbeddingsGenerationStubs.discourse_service(discourse_model, "this is a test", [1] * 1024)

      expect(subject.can_generate_embeddings?(discourse_model)).to eq(true)
    end
  end
end
