# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::EmbeddingsModuleValidator do
  let(:validator) { described_class.new }

  describe "#can_generate_embeddings?" do
    it "returns true if embeddings can be generated" do
      stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent?key=",
      ).to_return(status: 200, body: { embedding: { values: [1, 2, 3] } }.to_json)
      expect(validator.can_generate_embeddings?("gemini")).to eq(true)
    end
  end
end
