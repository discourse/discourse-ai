# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::OpenRouter do
  fab!(:user)
  fab!(:open_router_model)

  subject(:endpoint) { described_class.new(open_router_model) }

  it "supports provider quantization and order selection" do
    open_router_model.provider_params["provider_quantizations"] = "int8,int16"
    open_router_model.provider_params["provider_order"] = "Google, Amazon Bedrock"
    open_router_model.save!

    parsed_body = nil
    stub_request(:post, open_router_model.url).with(
      body: proc { |body| parsed_body = JSON.parse(body, symbolize_names: true) },
      headers: {
        "Content-Type" => "application/json",
        "X-Title" => "Discourse AI",
        "HTTP-Referer" => "https://www.discourse.org/ai",
        "Authorization" => "Bearer 123",
      },
    ).to_return(
      status: 200,
      body: { "choices" => [message: { role: "assistant", content: "world" }] }.to_json,
    )

    proxy = DiscourseAi::Completions::Llm.proxy("custom:#{open_router_model.id}")
    result = proxy.generate("hello", user: user)

    expect(result).to eq("world")

    expected = {
      model: "openrouter-1.0",
      messages: [
        { role: "system", content: "You are a helpful bot" },
        { role: "user", content: "hello" },
      ],
      provider: {
        quantizations: %w[int8 int16],
        order: ["Google", "Amazon Bedrock"],
      },
    }

    expect(parsed_body).to eq(expected)
  end
end
