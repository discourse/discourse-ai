# frozen_string_literal: true

require_relative "endpoint_compliance"

class OpenAiMock < EndpointMock
  def response(content, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [content] }
      else
        { content: content }
      end

    {
      id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
      object: "chat.completion",
      created: 1_678_464_820,
      model: "gpt-3.5-turbo-0301",
      usage: {
        prompt_tokens: 8,
        completion_tokens: 13,
        total_tokens: 499,
      },
      choices: [
        { message: { role: "assistant" }.merge(message_content), finish_reason: "stop", index: 0 },
      ],
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: request_body(prompt, tool_call: tool_call))
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta, finish_reason: nil, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [delta] }
      else
        { content: delta }
      end

    +"data: " << {
      id: "chatcmpl-#{SecureRandom.hex}",
      object: "chat.completion.chunk",
      created: 1_681_283_881,
      model: "gpt-3.5-turbo-0301",
      choices: [{ delta: message_content }],
      finish_reason: finish_reason,
      index: 0,
    }.to_json
  end

  def stub_raw(chunks, body_blk: nil)
    stub = WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions")
    stub.with(body: body_blk) if body_blk
    stub.to_return(status: 200, body: chunks)
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "stop_sequence", tool_call: tool_call)
        else
          stream_line(deltas[index], tool_call: tool_call)
        end
      end

    chunks = (chunks.join("\n\n") << "data: [DONE]").split("")

    WebMock
      .stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: request_body(prompt, stream: true, tool_call: tool_call))
      .to_return(status: 200, body: chunks)

    yield if block_given?
  end

  def tool_deltas
    [
      { id: tool_id, function: {} },
      { id: tool_id, function: { name: "get_weather", arguments: "" } },
      { id: tool_id, function: { arguments: "" } },
      { id: tool_id, function: { arguments: "{" } },
      { id: tool_id, function: { arguments: " \"location\": \"Sydney\"" } },
      { id: tool_id, function: { arguments: " ,\"unit\": \"c\" }" } },
    ]
  end

  def tool_response
    {
      id: tool_id,
      function: {
        name: "get_weather",
        arguments: { location: "Sydney", unit: "c" }.to_json,
      },
    }
  end

  def tool_id
    "tool_0"
  end

  def tool_payload
    {
      type: "function",
      function: {
        name: "get_weather",
        description: "Get the weather in a city",
        parameters: {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: "the city name",
            },
            unit: {
              type: "string",
              description: "the unit of measurement celcius c or fahrenheit f",
              enum: %w[c f],
            },
          },
          required: %w[location unit],
        },
      },
    }
  end

  def request_body(prompt, stream: false, tool_call: false)
    model
      .default_options
      .merge(messages: prompt)
      .tap do |b|
        if stream
          b[:stream] = true
          b[:stream_options] = { include_usage: true }
        end
        b[:tools] = [tool_payload] if tool_call
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAi do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model) { Fabricate(:llm_model) }

  let(:echo_tool) do
    {
      name: "echo",
      description: "echo something",
      parameters: [{ name: "text", type: "string", description: "text to echo", required: true }],
    }
  end

  let(:tools) { [echo_tool] }

  let(:open_ai_mock) { OpenAiMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::ChatGpt, user)
  end

  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  describe "repeat calls" do
    it "can properly reset context" do
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      tools = [
        {
          name: "echo",
          description: "echo something",
          parameters: [
            { name: "text", type: "string", description: "text to echo", required: true },
          ],
        },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "echo hello"],
          tools: tools,
        )

      response = {
        id: "chatcmpl-9JxkAzzaeO4DSV3omWvok9TKhCjBH",
        object: "chat.completion",
        created: 1_714_544_914,
        model: "gpt-4-turbo-2024-04-09",
        choices: [
          {
            index: 0,
            message: {
              role: "assistant",
              content: nil,
              tool_calls: [
                {
                  id: "call_I8LKnoijVuhKOM85nnEQgWwd",
                  type: "function",
                  function: {
                    name: "echo",
                    arguments: "{\"text\":\"hello\"}",
                  },
                },
              ],
            },
            logprobs: nil,
            finish_reason: "tool_calls",
          },
        ],
        usage: {
          prompt_tokens: 55,
          completion_tokens: 13,
          total_tokens: 68,
        },
        system_fingerprint: "fp_ea6eb70039",
      }.to_json

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(body: response)

      result = llm.generate(prompt, user: user)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "call_I8LKnoijVuhKOM85nnEQgWwd",
          name: "echo",
          parameters: {
            text: "hello",
          },
        )

      expect(result).to eq(tool_call)

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        body: { choices: [message: { content: "OK" }] }.to_json,
      )

      result = llm.generate(prompt, user: user)

      expect(result).to eq("OK")
    end
  end

  describe "forced tool use" do
    it "can properly force tool use" do
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      tools = [
        {
          name: "echo",
          description: "echo something",
          parameters: [
            { name: "text", type: "string", description: "text to echo", required: true },
          ],
        },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "echo hello"],
          tools: tools,
          tool_choice: "echo",
        )

      response = {
        id: "chatcmpl-9JxkAzzaeO4DSV3omWvok9TKhCjBH",
        object: "chat.completion",
        created: 1_714_544_914,
        model: "gpt-4-turbo-2024-04-09",
        choices: [
          {
            index: 0,
            message: {
              role: "assistant",
              content: nil,
              tool_calls: [
                {
                  id: "call_I8LKnoijVuhKOM85nnEQgWwd",
                  type: "function",
                  function: {
                    name: "echo",
                    arguments: "{\"text\":\"h<e>llo\"}",
                  },
                },
              ],
            },
            logprobs: nil,
            finish_reason: "tool_calls",
          },
        ],
        usage: {
          prompt_tokens: 55,
          completion_tokens: 13,
          total_tokens: 68,
        },
        system_fingerprint: "fp_ea6eb70039",
      }.to_json

      body_json = nil
      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body: proc { |body| body_json = JSON.parse(body, symbolize_names: true) },
      ).to_return(body: response)

      result = llm.generate(prompt, user: user)

      expect(body_json[:tool_choice]).to eq({ type: "function", function: { name: "echo" } })

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(55)
      expect(log.response_tokens).to eq(13)

      expected =
        DiscourseAi::Completions::ToolCall.new(
          id: "call_I8LKnoijVuhKOM85nnEQgWwd",
          name: "echo",
          parameters: {
            text: "h<e>llo",
          },
        )

      expect(result).to eq(expected)

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        body: { choices: [message: { content: "OK" }] }.to_json,
      )

      result = llm.generate(prompt, user: user)

      expect(result).to eq("OK")
    end
  end

  describe "image support" do
    it "can handle images" do
      model = Fabricate(:llm_model, vision_enabled: true)
      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are image bot",
          messages: [type: :user, id: "user1", content: "hello", upload_ids: [upload100x100.id]],
        )

      encoded = prompt.encoded_uploads(prompt.messages.last)

      parsed_body = nil

      stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
      ).to_return(status: 200, body: { choices: [message: { content: "nice pic" }] }.to_json)

      completion = llm.generate(prompt, user: user)

      expect(completion).to eq("nice pic")
      expected_body = {
        model: "gpt-4-turbo",
        messages: [
          { role: "system", content: "You are image bot" },
          {
            role: "user",
            content: [
              {
                type: "image_url",
                image_url: {
                  url: "data:#{encoded[0][:mime_type]};base64,#{encoded[0][:base64]}",
                },
              },
              { type: "text", text: "hello" },
            ],
            name: "user1",
          },
        ],
      }
      expect(parsed_body).to eq(expected_body)
    end
  end

  describe "#perform_completion!" do
    context "when using XML tool calls format" do
      let(:xml_tool_call_response) { <<~XML }
        <function_calls>
        <invoke>
        <tool_name>get_weather</tool_name>
        <parameters>
        <location>Sydney</location>
        <unit>c</unit>
        </parameters>
        </invoke>
        </function_calls>
      XML

      it "parses XML tool calls" do
        response = {
          id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
          object: "chat.completion",
          created: 1_678_464_820,
          model: "gpt-3.5-turbo-0301",
          usage: {
            prompt_tokens: 8,
            completion_tokens: 13,
            total_tokens: 499,
          },
          choices: [
            {
              message: {
                role: "assistant",
                content: xml_tool_call_response,
              },
              finish_reason: "stop",
              index: 0,
            },
          ],
        }.to_json

        endpoint.llm_model.update!(provider_params: { disable_native_tools: true })
        body = nil
        open_ai_mock.stub_raw(response, body_blk: proc { |inner_body| body = inner_body })

        dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: tools))
        tool_call = endpoint.perform_completion!(dialect, user)

        body_parsed = JSON.parse(body, symbolize_names: true)
        expect(body_parsed[:tools]).to eq(nil)

        expect(body_parsed[:messages][0][:content]).to include("<function_calls>")

        expect(tool_call.name).to eq("get_weather")
        expect(tool_call.parameters).to eq({ location: "Sydney", unit: "c" })
      end
    end

    context "when using regular mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.regular_mode_simple_prompt(open_ai_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(open_ai_mock)
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(open_ai_mock)
        end

        it "will automatically recover from a bad payload" do
          called = false

          # this should not happen, but lets ensure nothing bad happens
          # the row with test1 is invalid json
          raw_data = <<~TEXT.strip
            d|a|t|a|:| |{|"choices":[{"delta":{"content":"test,"}}]}

            data: {"choices":[{"delta":{"content":"test|1| |,"}}]

            data: {"choices":[{"delta":|{"content":"test2 ,"}}]}

            data: {"choices":[{"delta":{"content":"test3,"}}]|}

            data: {"choices":[{|"|d|elta":{"content":"test4"}}]|}

            data: [D|ONE]
          TEXT

          chunks = raw_data.split("|")

          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(chunks)

            partials = []

            endpoint.perform_completion!(compliance.dialect, user) { |partial| partials << partial }

            called = true
            expect(partials.join).to eq("test,test2 ,test3,test4")
          end
          expect(called).to be(true)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.streaming_mode_tools(open_ai_mock)
        end

        it "properly handles multiple tool calls" do
          raw_data = <<~TEXT.strip
              data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"role":"assistant","content":null},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_3Gyr3HylFJwfrtKrL6NaIit1","type":"function","function":{"name":"search","arguments":""}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"se"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"arch_"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"query\\""}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":": \\"D"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"iscou"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"rse AI"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":" bot"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"}"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"id":"call_H7YkbgYurHpyJqzwUN4bghwN","type":"function","function":{"name":"search","arguments":""}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"{\\"qu"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"ery\\":"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":" \\"Disc"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"ours"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"e AI "}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"bot2\\"}"}}]},"logprobs":null,"finish_reason":null}]}

  data: {"id":"chatcmpl-8xjcr5ZOGZ9v8BDYCx0iwe57lJAGk","object":"chat.completion.chunk","created":1709247429,"model":"gpt-4-0125-preview","system_fingerprint":"fp_91aa3742b1","choices":[{"index":0,"delta":{},"logprobs":null,"finish_reason":"tool_calls"}]}

  data: [DONE]
TEXT

          open_ai_mock.stub_raw(raw_data)
          response = []

          dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: tools))

          endpoint.perform_completion!(dialect, user) { |partial| response << partial }

          tool_calls = [
            DiscourseAi::Completions::ToolCall.new(
              name: "search",
              id: "call_3Gyr3HylFJwfrtKrL6NaIit1",
              parameters: {
                search_query: "Discourse AI bot",
              },
            ),
            DiscourseAi::Completions::ToolCall.new(
              name: "search",
              id: "call_H7YkbgYurHpyJqzwUN4bghwN",
              parameters: {
                query: "Discourse AI bot2",
              },
            ),
          ]

          expect(response).to eq(tool_calls)
        end

        it "properly handles newlines" do
          response = <<~TEXT.strip
            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":":\\n\\n"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"```"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"ruby"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"\\n"},"logprobs":null,"finish_reason":null}],"usage":null}

            data: {"id":"chatcmpl-ASngi346UA9k006bF6GBRV66tEJfQ","object":"chat.completion.chunk","created":1731427548,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_159d8341cc","choices":[{"index":0,"delta":{"content":"def"},"logprobs":null,"finish_reason":null}],"usage":null}
         TEXT

          open_ai_mock.stub_raw(response)
          partials = []

          dialect = compliance.dialect(prompt: compliance.generic_prompt)
          endpoint.perform_completion!(dialect, user) { |partial| partials << partial }

          expect(partials).to eq([":\n\n", "```", "ruby", "\n", "def"])
        end

        it "uses proper token accounting" do
          response = <<~TEXT.strip
            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[{"index":0,"delta":{"role":"assistant","content":""},"logprobs":null,"finish_reason":null}],"usage":null}|

            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[{"index":0,"delta":{"content":"Hello"},"logprobs":null,"finish_reason":null}],"usage":null}|

            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[{"index":0,"delta":{},"logprobs":null,"finish_reason":"stop"}],"usage":null}|

            data: {"id":"chatcmpl-9OZidiHncpBhhNMcqCus9XiJ3TkqR","object":"chat.completion.chunk","created":1715644203,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_729ea513f7","choices":[],"usage":{"prompt_tokens":20,"completion_tokens":9,"total_tokens":29}}|

            data: [DONE]
          TEXT

          chunks = response.split("|")
          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(chunks)
            partials = []

            dialect = compliance.dialect(prompt: compliance.generic_prompt)
            endpoint.perform_completion!(dialect, user) { |partial| partials << partial }

            expect(partials).to eq(["Hello"])

            log = AiApiAuditLog.order("id desc").first

            expect(log.request_tokens).to eq(20)
            expect(log.response_tokens).to eq(9)
          end
        end

        it "properly handles multiple params in partial tool calls" do
          # this is not working and it is driving me nuts so I will use a sledghammer
          # text = plugin_file_from_fixtures("openai_artifact_call.txt", "bot")

          path = File.join(__dir__, "../../../fixtures/bot", "openai_artifact_call.txt")
          text = File.read(path)

          partials = []
          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(text.scan(/.*\n/))

            dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: tools))
            endpoint.perform_completion!(dialect, user, partial_tool_calls: true) do |partial|
              partials << partial.dup
            end
          end

          expect(partials.compact.length).to eq(128)

          params =
            partials
              .map { |p| p.parameters if p.is_a?(DiscourseAi::Completions::ToolCall) && p.partial? }
              .compact

          lengths = {}
          params.each do |p|
            p.each do |k, v|
              if lengths[k] && lengths[k] > v.length
                expect(lengths[k]).to be > v.length
              else
                lengths[k] = v.length
              end
            end
          end

          audit_log = AiApiAuditLog.order("id desc").first
          expect(audit_log.cached_tokens).to eq(33)
        end

        it "properly handles spaces in tools payload and partial tool calls" do
          raw_data = <<~TEXT.strip
            data: {"choices":[{"index":0,"delta":{"role":"assistant","content":null,"tool_calls":[{"index":0,"id":"func_id","type":"function","function":{"name":"go|ogle","arg|uments":""}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "{\\""}}]}}]}

            data: {"ch|oices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "query"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "\\":\\""}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "Ad"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "a|b"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "as"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": |"| "}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "9"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "."}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"argume|nts": "1"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": [{"index": 0, "function": {"arguments": "\\"}"}}]}}]}

            data: {"choices": [{"index": 0, "delta": {"tool_calls": []}}]}

            data: [D|ONE]
          TEXT

          chunks = raw_data.split("|")

          open_ai_mock.with_chunk_array_support do
            open_ai_mock.stub_raw(chunks)
            partials = []

            dialect = compliance.dialect(prompt: compliance.generic_prompt(tools: tools))
            endpoint.perform_completion!(dialect, user, partial_tool_calls: true) do |partial|
              partials << partial.dup
            end

            tool_call =
              DiscourseAi::Completions::ToolCall.new(
                id: "func_id",
                name: "google",
                parameters: {
                  query: "Adabas 9.1",
                },
              )

            expect(partials.last).to eq(tool_call)

            progress = partials.map { |p| p.parameters[:query] }
            expect(progress).to eq(["Ad", "Adabas", "Adabas 9.", "Adabas 9.1"])
          end
        end
      end
    end
  end
end
