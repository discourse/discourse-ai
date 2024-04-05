# frozen_string_literal: true
require_relative "endpoint_compliance"

RSpec.describe DiscourseAi::Completions::Endpoints::Cohere do
  let(:llm) { DiscourseAi::Completions::Llm.proxy("cohere:command-r-plus") }
  fab!(:user)

  let(:prompt) do
    DiscourseAi::Completions::Prompt.new(
      "You are hello bot",
      messages: [
        { type: :user, id: "user1", content: "hello" },
        { type: :model, content: "hi user" },
        { type: :user, id: "user1", content: "thanks" },
      ],
    )
  end

  before { SiteSetting.ai_cohere_api_key = "ABC" }

  it "is able to perform streaming completions" do
    body = <<~TEXT
      {"is_finished":false,"event_type":"stream-start","generation_id":"eb889b0f-c27d-45ea-98cf-567bdb7fc8bf"}
      {"is_finished":false,"event_type":"text-generation","text":"You"}
      {"is_finished":false,"event_type":"text-generation","text":"'re"}
      {"is_finished":false,"event_type":"text-generation","text":" welcome"}
      {"is_finished":false,"event_type":"text-generation","text":"!"}
      {"is_finished":false,"event_type":"text-generation","text":" Is"}
      {"is_finished":false,"event_type":"text-generation","text":" there"}
      {"is_finished":false,"event_type":"text-generation","text":" anything"}|
      {"is_finished":false,"event_type":"text-generation","text":" else"}
      {"is_finished":false,"event_type":"text-generation","text":" I"}
      {"is_finished":false,"event_type":"text-generation","text":" can"}
      {"is_finished":false,"event_type":"text-generation","text":" help"}|
      {"is_finished":false,"event_type":"text-generation","text":" you"}
      {"is_finished":false,"event_type":"text-generation","text":" with"}
      {"is_finished":false,"event_type":"text-generation","text":"?"}|
      {"is_finished":true,"event_type":"stream-end","response":{"response_id":"d235db17-8555-493b-8d91-e601f76de3f9","text":"You're welcome! Is there anything else I can help you with?","generation_id":"eb889b0f-c27d-45ea-98cf-567bdb7fc8bf","chat_history":[{"role":"USER","message":"user1: hello"},{"role":"CHATBOT","message":"hi user"},{"role":"USER","message":"user1: thanks"},{"role":"CHATBOT","message":"You're welcome! Is there anything else I can help you with?"}],"token_count":{"prompt_tokens":29,"response_tokens":14,"total_tokens":43,"billed_tokens":28},"meta":{"api_version":{"version":"1"},"billed_units":{"input_tokens":14,"output_tokens":14}}},"finish_reason":"COMPLETE"}
    TEXT

    parsed_body = nil
    result = +""

    EndpointMock.with_chunk_array_support do
      stub_request(:post, "https://api.cohere.ai/v1/chat").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: body.split("|"))

      result = llm.generate(prompt, user: user) { |partial, cancel| result << partial }
    end

    expect(parsed_body[:preamble]).to eq("You are hello bot")
    expect(parsed_body[:chat_history]).to eq(
      [{ role: "USER", message: "user1: hello" }, { role: "CHATBOT", message: "hi user" }],
    )
    expect(parsed_body[:message]).to eq("user1: thanks")

    expect(result).to eq("You're welcome! Is there anything else I can help you with?")
    audit = AiApiAuditLog.order("id desc").first

    # billing should be picked
    expect(audit.request_tokens).to eq(14)
    expect(audit.response_tokens).to eq(14)
  end

  it "is able to perform non streaming completions" do
    body = {
      response_id: "0a90275b-273d-4690-abce-8018edcec7d0",
      text: "You're welcome! How can I help you today?",
      generation_id: "cc2742f7-622c-4e42-8fd4-d95b21012e52",
      chat_history: [
        { role: "USER", message: "user1: hello" },
        { role: "CHATBOT", message: "hi user" },
        { role: "USER", message: "user1: thanks" },
        { role: "CHATBOT", message: "You're welcome! How can I help you today?" },
      ],
      finish_reason: "COMPLETE",
      token_count: {
        prompt_tokens: 29,
        response_tokens: 11,
        total_tokens: 40,
        billed_tokens: 25,
      },
      meta: {
        api_version: {
          version: "1",
        },
        billed_units: {
          input_tokens: 14,
          output_tokens: 11,
        },
      },
    }.to_json

    parsed_body = nil
    stub_request(:post, "https://api.cohere.ai/v1/chat").with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer ABC",
      },
    ).to_return(status: 200, body: body)

    result = llm.generate(prompt, user: user)

    expect(parsed_body[:preamble]).to eq("You are hello bot")
    expect(parsed_body[:chat_history]).to eq(
      [{ role: "USER", message: "user1: hello" }, { role: "CHATBOT", message: "hi user" }],
    )
    expect(parsed_body[:message]).to eq("user1: thanks")

    expect(result).to eq("You're welcome! How can I help you today?")
    audit = AiApiAuditLog.order("id desc").first

    # billing should be picked
    expect(audit.request_tokens).to eq(14)
    expect(audit.response_tokens).to eq(11)
  end
end
