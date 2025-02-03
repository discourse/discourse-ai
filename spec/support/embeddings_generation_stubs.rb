# frozen_string_literal: true

class EmbeddingsGenerationStubs
  class << self
    def hugging_face_service(string, embedding)
      WebMock
        .stub_request(:post, "https://test.com/embeddings")
        .with(body: JSON.dump({ inputs: string, truncate: true }))
        .to_return(status: 200, body: JSON.dump([embedding]))
    end

    def openai_service(model, string, embedding, extra_args: {})
      WebMock
        .stub_request(:post, "https://api.openai.com/v1/embeddings")
        .with(body: JSON.dump({ model: model, input: string }.merge(extra_args)))
        .to_return(status: 200, body: JSON.dump({ data: [{ embedding: embedding }] }))
    end

    def gemini_service(api_key, string, embedding)
      WebMock
        .stub_request(
          :post,
          "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent\?key\=#{api_key}",
        )
        .with(body: JSON.dump({ content: { parts: [{ text: string }] } }))
        .to_return(status: 200, body: JSON.dump({ embedding: { values: embedding } }))
    end

    def cloudflare_service(string, embedding)
      WebMock
        .stub_request(:post, "https://test.com/embeddings")
        .with(body: JSON.dump({ text: [string] }))
        .to_return(status: 200, body: JSON.dump({ result: { data: [embedding] } }))
    end
  end
end
