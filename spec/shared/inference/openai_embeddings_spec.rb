# frozen_string_literal: true
require "rails_helper"

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
        "Accept" => "*/*",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "Api-Key" => "123456",
        "Content-Type" => "application/json",
        "User-Agent" => "Faraday v2.7.6",
      },
    ).to_return(status: 200, body: body_json, headers: {})

    result = DiscourseAi::Inference::OpenAiEmbeddings.perform!("hello")

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

    stub_request(:post, "https://api.openai.com/v1/embeddings").with(
      body: "{\"model\":\"text-embedding-ada-002\",\"input\":\"hello\"}",
      headers: {
        "Accept" => "*/*",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "Authorization" => "Bearer 123456",
        "Content-Type" => "application/json",
        "User-Agent" => "Faraday v2.7.6",
      },
    ).to_return(status: 200, body: body_json, headers: {})

    result = DiscourseAi::Inference::OpenAiEmbeddings.perform!("hello")

    expect(result[:usage]).to eq({ prompt_tokens: 1, total_tokens: 1 })
    expect(result[:data].first).to eq({ object: "embedding", embedding: [0.0, 0.1] })
  end
end
