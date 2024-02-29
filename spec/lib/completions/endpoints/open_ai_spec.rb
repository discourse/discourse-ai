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
        prompt_tokens: 337,
        completion_tokens: 162,
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

  def stub_raw(chunks)
    WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: chunks,
    )
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
      { id: tool_id, function: { name: "get_weather", arguments: "" } },
      { id: tool_id, function: { name: "get_weather", arguments: "{" } },
      { id: tool_id, function: { name: "get_weather", arguments: " \"location\": \"Sydney\"" } },
      { id: tool_id, function: { name: "get_weather", arguments: " ,\"unit\": \"c\" }" } },
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
    "eujbuebfe"
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
        b[:stream] = true if stream
        b[:tools] = [tool_payload] if tool_call
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAi do
  subject(:endpoint) do
    described_class.new("gpt-3.5-turbo", DiscourseAi::Tokenizer::OpenAiTokenizer)
  end

  fab!(:user) { Fabricate(:user) }

  let(:open_ai_mock) { OpenAiMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::ChatGpt, user)
  end

  describe "#perform_completion!" do
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

        it "properly handles spaces in tools payload" do
          raw_data = <<~TEXT.strip
            data: {"choices":[{"index":0,"delta":{"role":"assistant","content":null,"tool_calls":[{"index":0,"id":"func_id","type":"function","function":{"name":"google","arguments":""}}]}}]}

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

            endpoint.perform_completion!(compliance.dialect, user) do |partial, x, y|
              partials << partial
            end

            expect(partials.length).to eq(1)

            function_call = (<<~TXT).strip
            <function_calls>
            <invoke>
            <tool_name>google</tool_name>
            <tool_id>func_id</tool_id>
            <parameters>
            <query>Adabas 9.1</query>
            </parameters>
            </invoke>
            </function_calls>
            TXT

            expect(partials[0].strip).to eq(function_call)
          end
        end
      end
    end
  end
end
