# frozen_string_literal: true

describe DiscourseAi::Inference::OpenAiEmbeddings do
  it "supports azure embeddings" do
    SiteSetting.ai_openai_embeddings_url =
      "https://my-company.openai.azure.com/openai/deployments/embeddings-deployment/embeddings?api-version=2023-05-15"
    SiteSetting.ai_openai_api_key = "123456"

    body_json = {
      usage: {
        prompt_tokens: 1,
        total_tokens: 1,
      },
      data: [{ object: "embedding", embedding: [0.0, 0.1] }],
    }.to_json

    stub_request(
      :post,
      "https://my-company.openai.azure.com/openai/deployments/embeddings-deployment/embeddings?api-version=2023-05-15",
    ).with(
      body: "{\"model\":\"text-embedding-ada-002\",\"input\":\"hello\"}",
      headers: {
        "Api-Key" => "123456",
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: body_json, headers: {})

    result =
      DiscourseAi::Inference::OpenAiEmbeddings.perform!("hello", model: "text-embedding-ada-002")

    expect(result[:usage]).to eq({ prompt_tokens: 1, total_tokens: 1 })
    expect(result[:data].first).to eq({ object: "embedding", embedding: [0.0, 0.1] })
  end

  it "supports openai embeddings" do
    SiteSetting.ai_openai_api_key = "123456"

    body_json = {
      usage: {
        prompt_tokens: 1,
        total_tokens: 1,
      },
      data: [{ object: "embedding", embedding: [0.0, 0.1] }],
    }.to_json

    body = { model: "text-embedding-ada-002", input: "hello", dimensions: 1000 }.to_json

    stub_request(:post, "https://api.openai.com/v1/embeddings").with(
      body: body,
      headers: {
        "Authorization" => "Bearer 123456",
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: body_json, headers: {})

    result =
      DiscourseAi::Inference::OpenAiEmbeddings.perform!(
        "hello",
        model: "text-embedding-ada-002",
        dimensions: 1000,
      )

    expect(result[:usage]).to eq({ prompt_tokens: 1, total_tokens: 1 })
    expect(result[:data].first).to eq({ object: "embedding", embedding: [0.0, 0.1] })
  end
end
