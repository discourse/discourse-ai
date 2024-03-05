# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::AnthropicMessages do
  let(:llm) { DiscourseAi::Completions::Llm.proxy("anthropic:claude-3-opus") }

  let(:prompt) do
    DiscourseAi::Completions::Prompt.new(
      "You are hello bot",
      messages: [type: :user, id: "user1", content: "hello"],
    )
  end

  before { SiteSetting.ai_anthropic_api_key = "123" }

  it "does not eat spaces with tool calls" do
    body = <<~STRING
      event: message_start
      data: {"type":"message_start","message":{"id":"msg_019kmW9Q3GqfWmuFJbePJTBR","type":"message","role":"assistant","content":[],"model":"claude-3-opus-20240229","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":347,"output_tokens":1}}}

      event: content_block_start
      data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

      event: ping
      data: {"type": "ping"}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"<function"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"_"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"calls"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\n"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"<invoke"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\n"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"<tool"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"_"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"name"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"google"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"</tool"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"_"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"name"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\n"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"<parameters"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\n"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"<query"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"top"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" "}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"10"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" "}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"things"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" to"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" do"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" in"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" japan"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" for"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" tourists"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"</query"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\n"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"</parameters"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\n"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"</invoke"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":">"}}

      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\\n"}}

      event: content_block_stop
      data: {"type":"content_block_stop","index":0}

      event: message_delta
      data: {"type":"message_delta","delta":{"stop_reason":"stop_sequence","stop_sequence":"</function_calls>"},"usage":{"output_tokens":57}}

      event: message_stop
      data: {"type":"message_stop"}
    STRING

    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(status: 200, body: body)

    result = +""
    llm.generate(prompt, user: Discourse.system_user) { |partial| result << partial }

    expected = (<<~TEXT).strip
      <function_calls>
      <invoke>
      <tool_name>google</tool_name>
      <tool_id>google</tool_id>
      <parameters>
      <query>top 10 things to do in japan for tourists</query>
      </parameters>
      </invoke>
      </function_calls>
    TEXT

    expect(result.strip).to eq(expected)
  end

  it "can stream a response" do
    body = (<<~STRING).strip
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY", "type": "message", "role": "assistant", "content": [], "model": "claude-3-opus-20240229", "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 25, "output_tokens": 1}}}

      event: content_block_start
      data: {"type": "content_block_start", "index":0, "content_block": {"type": "text", "text": ""}}

      event: ping
      data: {"type": "ping"}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "!"}}

      event: content_block_stop
      data: {"type": "content_block_stop", "index": 0}

      event: message_delta
      data: {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence":null, "usage":{"output_tokens": 15}}}

      event: message_stop
      data: {"type": "message_stop"}
    STRING

    parsed_body = nil

    stub_request(:post, "https://api.anthropic.com/v1/messages").with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    result = +""
    llm.generate(prompt, user: Discourse.system_user) { |partial, cancel| result << partial }

    expect(result).to eq("Hello!")

    expected_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 3000,
      stop_sequences: ["</function_calls>"],
      messages: [{ role: "user", content: "user1: hello" }],
      system: "You are hello bot",
      stream: true,
    }
    expect(parsed_body).to eq(expected_body)

    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.request_tokens).to eq(25)
    expect(log.response_tokens).to eq(15)
  end

  it "can operate in regular mode" do
    body = <<~STRING
      {
        "content": [
          {
            "text": "Hello!",
            "type": "text"
          }
        ],
        "id": "msg_013Zva2CMHLNnXjNJJKqJ2EF",
        "model": "claude-3-opus-20240229",
        "role": "assistant",
        "stop_reason": "end_turn",
        "stop_sequence": null,
        "type": "message",
        "usage": {
          "input_tokens": 10,
          "output_tokens": 25
        }
      }
    STRING

    parsed_body = nil
    stub_request(:post, "https://api.anthropic.com/v1/messages").with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    result = llm.generate(prompt, user: Discourse.system_user)
    expect(result).to eq("Hello!")

    expected_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 3000,
      stop_sequences: ["</function_calls>"],
      messages: [{ role: "user", content: "user1: hello" }],
      system: "You are hello bot",
    }
    expect(parsed_body).to eq(expected_body)

    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.request_tokens).to eq(10)
    expect(log.response_tokens).to eq(25)
  end
end
