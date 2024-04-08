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

  let(:weather_tool) do
    {
      name: "weather",
      description: "lookup weather in a city",
      parameters: [{ name: "city", type: "string", description: "city name", required: true }],
    }
  end

  let(:prompt_with_tools) do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are weather bot",
        messages: [
          { type: :user, id: "user1", content: "what is the weather in sydney and melbourne?" },
        ],
      )

    prompt.tools = [weather_tool]
    prompt
  end

  before { SiteSetting.ai_cohere_api_key = "ABC" }

  it "is able to run tools in streaming mode" do
    body = <<~TEXT
      {"is_finished":false,"event_type":"stream-start","generation_id":"d8dd0557-b51d-483c-b855-6ce7fcc5b19f"}
      {"is_finished":false,"event_type":"tool-calls-generation","tool_calls":[{"name":"weather","parameters":{"city":"Sydney"}},{"name":"weather","parameters":{"city":"Melbourne"}}]}
      {"is_finished":true,"event_type":"stream-end","response":{"response_id":"002516fe-6dc1-48d5-a9a9-031f5132a79f","text":"","generation_id":"d8dd0557-b51d-483c-b855-6ce7fcc5b19f","chat_history":[],"meta":{"api_version":{"version":"1"},"billed_units":{"input_tokens":24,"output_tokens":12},"tokens":{"output_tokens":12}},"tool_calls":[{"name":"weather","parameters":{"city":"Sydney"}},{"name":"weather","parameters":{"city":"Melbourne"}}]},"finish_reason":"COMPLETE"}
    TEXT

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

    response = +""
    llm.generate(prompt_with_tools, user: user) { |partial| response << partial }

    expect(parsed_body[:tools]).to be_present

    expected = <<~XML
      <function_calls>
      <invoke>
      <tool_name>weather</tool_name>
      <parameters>
      <city>Sydney</city>
      </parameters>
      <tool_id>tool_0</tool_id>
      </invoke>
      <invoke>
      <tool_name>weather</tool_name>
      <parameters>
      <city>Melbourne</city>
      </parameters>
      <tool_id>tool_1</tool_id>
      </invoke>
      </function_calls>
    XML

    expect(response.strip).to eq(expected.strip)
  end

  it "is able to run tools" do
    body = {
      response_id: "c8542aec-d528-4ed0-92c9-dc863a860685",
      text: "",
      generation_id: "e3107038-b9d4-4ae8-a459-23f64ed512ab",
      chat_history: [],
      finish_reason: "COMPLETE",
      meta: {
        api_version: {
          version: "1",
        },
        billed_units: {
          input_tokens: 24,
          output_tokens: 12,
        },
        tokens: {
          output_tokens: 12,
        },
      },
      tool_calls: [
        { name: "weather", parameters: { city: "Sydney" } },
        { name: "weather", parameters: { city: "Melbourne" } },
      ],
    }

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
    ).to_return(status: 200, body: body.to_json)

    result = llm.generate(prompt_with_tools, user: user)

    expect(parsed_body[:tools]).to eq(
      [
        {
          name: "weather",
          description: "lookup weather in a city",
          parameter_definitions: {
            city: {
              description: "city name",
              type: "str",
              required: true,
            },
          },
        },
      ],
    )

    expected = <<~XML
      <function_calls>
      <invoke>
      <tool_name>weather</tool_name>
      <parameters>
      <city>Sydney</city>
      </parameters>
      <tool_id>tool_0</tool_id>
      </invoke>
      <invoke>
      <tool_name>weather</tool_name>
      <parameters>
      <city>Melbourne</city>
      </parameters>
      <tool_id>tool_1</tool_id>
      </invoke>
      </function_calls>
    XML

    expect(result.strip).to eq(expected.strip)
  end

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

    result =
      llm.generate(
        prompt,
        user: user,
        temperature: 0.1,
        top_p: 0.5,
        max_tokens: 100,
        stop_sequences: ["stop"],
      )

    expect(parsed_body[:temperature]).to eq(0.1)
    expect(parsed_body[:p]).to eq(0.5)
    expect(parsed_body[:max_tokens]).to eq(100)
    expect(parsed_body[:stop_sequences]).to eq(["stop"])

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
