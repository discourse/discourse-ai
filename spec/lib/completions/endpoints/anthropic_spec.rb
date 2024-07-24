# frozen_string_literal: true
require_relative "endpoint_compliance"

RSpec.describe DiscourseAi::Completions::Endpoints::Anthropic do
  let(:url) { "https://api.anthropic.com/v1/messages" }
  fab!(:model) do
    Fabricate(
      :llm_model,
      url: "https://api.anthropic.com/v1/messages",
      name: "claude-3-opus",
      provider: "anthropic",
      api_key: "123",
      vision_enabled: true,
    )
  end
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{model.id}") }
  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  let(:prompt) do
    DiscourseAi::Completions::Prompt.new(
      "You are hello bot",
      messages: [type: :user, id: "user1", content: "hello"],
    )
  end

  let(:echo_tool) do
    {
      name: "echo",
      description: "echo something",
      parameters: [{ name: "text", type: "string", description: "text to echo", required: true }],
    }
  end

  let(:google_tool) do
    {
      name: "google",
      description: "google something",
      parameters: [
        { name: "query", type: "string", description: "text to google", required: true },
      ],
    }
  end

  let(:prompt_with_echo_tool) do
    prompt_with_tools = prompt
    prompt.tools = [echo_tool]
    prompt_with_tools
  end

  let(:prompt_with_google_tool) do
    prompt_with_tools = prompt
    prompt.tools = [echo_tool]
    prompt_with_tools
  end

  it "does not eat spaces with tool calls" do
    SiteSetting.ai_anthropic_native_tool_call_models = "claude-3-opus"
    body = <<~STRING
    event: message_start
    data: {"type":"message_start","message":{"id":"msg_01Ju4j2MiGQb9KV9EEQ522Y3","type":"message","role":"assistant","model":"claude-3-haiku-20240307","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1293,"output_tokens":1}}   }

    event: content_block_start
    data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01DjrShFRRHp9SnHYRFRc53F","name":"search","input":{}}      }

    event: ping
    data: {"type": "ping"}

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":""}            }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"searc"}              }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"h_qu"}        }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"er"} }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"y\\": \\"s"}      }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"am"}          }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":" "}          }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"sam\\""}          }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":", \\"cate"}         }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"gory"}   }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"\\": \\"gene"}               }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"ral\\"}"}           }

    event: content_block_stop
    data: {"type":"content_block_stop","index":0     }

    event: message_delta
    data: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":70}       }

    event: message_stop
    data: {"type":"message_stop"}
    STRING

    result = +""
    body = body.scan(/.*\n/)
    EndpointMock.with_chunk_array_support do
      stub_request(:post, url).to_return(status: 200, body: body)

      llm.generate(prompt_with_google_tool, user: Discourse.system_user) do |partial|
        result << partial
      end
    end

    expected = (<<~TEXT).strip
      <function_calls>
      <invoke>
      <tool_name>search</tool_name>
      <parameters><search_query>sam sam</search_query>
      <category>general</category></parameters>
      <tool_id>toolu_01DjrShFRRHp9SnHYRFRc53F</tool_id>
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

    stub_request(:post, url).with(
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
    llm.generate(prompt, user: Discourse.system_user, feature_name: "testing") do |partial, cancel|
      result << partial
    end

    expect(result).to eq("Hello!")

    expected_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 3000,
      messages: [{ role: "user", content: "user1: hello" }],
      system: "You are hello bot",
      stream: true,
    }
    expect(parsed_body).to eq(expected_body)

    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.feature_name).to eq("testing")
    expect(log.response_tokens).to eq(15)
    expect(log.request_tokens).to eq(25)
  end

  it "supports non streaming tool calls" do
    tool = {
      name: "calculate",
      description: "calculate something",
      parameters: [
        {
          name: "expression",
          type: "string",
          description: "expression to calculate",
          required: true,
        },
      ],
    }

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You a calculator",
        messages: [{ type: :user, id: "user1", content: "calculate 2758975 + 21.11" }],
        tools: [tool],
      )

    proxy = DiscourseAi::Completions::Llm.proxy("anthropic:claude-3-haiku")

    body = {
      id: "msg_01RdJkxCbsEj9VFyFYAkfy2S",
      type: "message",
      role: "assistant",
      model: "claude-3-haiku-20240307",
      content: [
        { type: "text", text: "Here is the calculation:" },
        {
          type: "tool_use",
          id: "toolu_012kBdhG4eHaV68W56p4N94h",
          name: "calculate",
          input: {
            expression: "2758975 + 21.11",
          },
        },
      ],
      stop_reason: "tool_use",
      stop_sequence: nil,
      usage: {
        input_tokens: 345,
        output_tokens: 65,
      },
    }.to_json

    stub_request(:post, url).to_return(body: body)

    result = proxy.generate(prompt, user: Discourse.system_user)

    expected = <<~TEXT.strip
      <function_calls>
      <invoke>
      <tool_name>calculate</tool_name>
      <parameters><expression>2758975 + 21.11</expression></parameters>
      <tool_id>toolu_012kBdhG4eHaV68W56p4N94h</tool_id>
      </invoke>
      </function_calls>
    TEXT

    expect(result.strip).to eq(expected)
  end

  it "can send images via a completion prompt" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are image bot",
        messages: [type: :user, id: "user1", content: "hello", upload_ids: [upload100x100.id]],
      )

    encoded = prompt.encoded_uploads(prompt.messages.last)

    request_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 3000,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/jpeg",
                data: encoded[0][:base64],
              },
            },
            { type: "text", text: "user1: hello" },
          ],
        },
      ],
      system: "You are image bot",
    }

    response_body = <<~STRING
      {
        "content": [
          {
            "text": "What a cool image",
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

    requested_body = nil
    stub_request(:post, url).with(
      body:
        proc do |req_body|
          requested_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
    ).to_return(status: 200, body: response_body)

    result = llm.generate(prompt, user: Discourse.system_user)

    expect(result).to eq("What a cool image")
    expect(requested_body).to eq(request_body)
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
    stub_request(:post, url).with(
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
