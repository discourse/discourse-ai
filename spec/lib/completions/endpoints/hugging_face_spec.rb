# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::HuggingFace do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::Llama2Tokenizer) }

  let(:model_name) { "Llama2-*-chat-hf" }
  let(:prompt) { <<~TEXT }
      [INST]<<SYS>>You are a helpful bot.<</SYS>>[/INST]
      [INST]Write 3 words[/INST]
    TEXT

  let(:request_body) do
    model
      .default_options
      .merge(inputs: prompt)
      .tap do |payload|
        payload[:parameters][:max_new_tokens] = (SiteSetting.ai_hugging_face_token_limit || 4_000) -
          model.prompt_size(prompt)
      end
      .to_json
  end
  let(:stream_request_body) do
    model
      .default_options
      .merge(inputs: prompt)
      .tap do |payload|
        payload[:parameters][:max_new_tokens] = (SiteSetting.ai_hugging_face_token_limit || 4_000) -
          model.prompt_size(prompt)
        payload[:stream] = true
      end
      .to_json
  end

  before { SiteSetting.ai_hugging_face_api_url = "https://test.dev" }

  def response(content)
    [{ generated_text: content }]
  end

  def stub_response(prompt, response_text)
    WebMock
      .stub_request(:post, "#{SiteSetting.ai_hugging_face_api_url}")
      .with(body: request_body)
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    +"data: " << {
      token: {
        id: 29_889,
        text: delta,
        logprob: -0.08319092,
        special: !!finish_reason,
      },
      generated_text: finish_reason ? response_text : nil,
      details: nil,
    }.to_json
  end

  def stub_streamed_response(prompt, deltas)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: true)
        else
          stream_line(deltas[index])
        end
      end

    chunks = chunks.join("\n\n")

    WebMock
      .stub_request(:post, "#{SiteSetting.ai_hugging_face_api_url}")
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  it_behaves_like "an endpoint that can communicate with a completion service"
end
