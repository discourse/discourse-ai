# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAi do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::OpenAiTokenizer) }

  let(:model_name) { "gpt-3.5-turbo" }
  let(:generic_prompt) { { insts: "You are a helpful bot.", input: "write 3 words" } }
  let(:dialect) { DiscourseAi::Completions::Dialects::ChatGpt.new(generic_prompt, model_name) }
  let(:prompt) { dialect.translate }

  let(:tool_deltas) do
    [
      { id: "get_weather", name: "get_weather", arguments: {} },
      { id: "get_weather", name: "get_weather", arguments: { location: "" } },
      { id: "get_weather", name: "get_weather", arguments: { location: "Sydney", unit: "c" } },
    ]
  end

  let(:tool_call) do
    { id: "get_weather", name: "get_weather", arguments: { location: "Sydney", unit: "c" } }
  end

  let(:request_body) do
    model
      .default_options
      .merge(messages: prompt)
      .tap do |b|
        b[:tools] = generic_prompt[:tools].map do |t|
          { type: "function", tool: t }
        end if generic_prompt[:tools]
      end
      .to_json
  end
  let(:stream_request_body) do
    model
      .default_options
      .merge(messages: prompt, stream: true)
      .tap do |b|
        b[:tools] = generic_prompt[:tools].map do |t|
          { type: "function", tool: t }
        end if generic_prompt[:tools]
      end
      .to_json
  end

  def response(content, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [{ function: content }] }
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
      .with(body: request_body)
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta, finish_reason: nil, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [{ function: delta }] }
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
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  it_behaves_like "an endpoint that can communicate with a completion service"
end
