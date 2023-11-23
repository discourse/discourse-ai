# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAI do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::OpenAiTokenizer) }

  let(:model_name) { "gpt-3.5-turbo" }
  let(:prompt) do
    [
      { role: "system", content: "You are a helpful bot." },
      { role: "user", content: "Write 3 words" },
    ]
  end

  let(:request_body) { model.default_options.merge(messages: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(messages: prompt, stream: true).to_json }

  def response(content)
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
        { message: { role: "assistant", content: content }, finish_reason: "stop", index: 0 },
      ],
    }
  end

  def stub_response(prompt, response_text)
    WebMock
      .stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: { model: model_name, messages: prompt })
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    +"data: " << {
      id: "chatcmpl-#{SecureRandom.hex}",
      object: "chat.completion.chunk",
      created: 1_681_283_881,
      model: "gpt-3.5-turbo-0301",
      choices: [{ delta: { content: delta } }],
      finish_reason: finish_reason,
      index: 0,
    }.to_json
  end

  def stub_streamed_response(prompt, deltas)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "stop_sequence")
        else
          stream_line(deltas[index])
        end
      end

    chunks = chunks.join("\n\n")

    WebMock
      .stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: model.default_options.merge(messages: prompt, stream: true).to_json)
      .to_return(status: 200, body: chunks)
  end

  it_behaves_like "an endpoint that can communicate with a completion service"
end
