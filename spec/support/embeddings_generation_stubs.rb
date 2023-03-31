# frozen_string_literal: true

class EmbeddingsGenerationStubs
  class << self
    def discourse_service(model, string, embedding)
      WebMock
        .stub_request(
          :post,
          "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
        )
        .with(body: JSON.dump({ model: model, content: string }))
        .to_return(status: 200, body: JSON.dump(embedding))
    end

    def openai_service(model, string, embedding)
      WebMock
        .stub_request(:post, "https://api.openai.com/v1/embeddings")
        .with(body: JSON.dump({ model: model, input: string }))
        .to_return(status: 200, body: JSON.dump({ data: [{ embedding: embedding }] }))
    end
  end
end
