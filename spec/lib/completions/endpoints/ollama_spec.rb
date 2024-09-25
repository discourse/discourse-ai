# frozen_string_literal: true

require_relative "endpoint_compliance"

class OllamaMock < EndpointMock
  def response(content)
    message_content = { content: content }

    {
      created_at: "2024-09-25T06:47:21.283028Z",
      model: "llama3.1",
      message: { role: "assistant" }.merge(message_content),
      done: true,
      done_reason: "stop",
      total_duration: 7639718541,
      load_duration: 299886663,
      prompt_eval_count: 18,
      prompt_eval_duration: 220447000,
      eval_count: 18,
      eval_duration: 220447000,
    }
  end

  def stub_response(prompt, response_text)
    WebMock
      .stub_request(:post, "http://api.ollama.ai/api/chat")
      .with(body: request_body(prompt))
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta)
    message_content = { content: delta }

    +{
      model: "llama3.1",
      created_at: "2024-09-25T06:47:21.283028Z",
      message: { role: "assistant" }.merge(message_content),
      done: false,
    }.to_json
  end

  def stub_raw(chunks)
    WebMock.stub_request(:post, "http://api.ollama.ai/api/chat").to_return(
      status: 200,
      body: chunks,
    )
  end

  def stub_streamed_response(prompt, deltas)
    chunks = deltas.each_with_index.map do |_, index|
      stream_line(deltas[index])
    end

    chunks = (chunks.join("\n\n") << {
      model: "llama3.1",
      created_at: "2024-09-25T06:47:21.283028Z",
      message: { role: "assistant", content: "" },
      done: true,
      done_reason: "stop",
      total_duration: 7639718541,
      load_duration: 299886663,
      prompt_eval_count: 18,
      prompt_eval_duration: 220447000,
      eval_count: 18,
      eval_duration: 220447000,
    }.to_json).split("")

    WebMock
      .stub_request(:post, "http://api.ollama.ai/api/chat")
      .with(body: request_body(prompt, stream: true))
      .to_return(status: 200, body: chunks)

    yield if block_given?
  end

  def request_body(prompt, stream: false)
    model
      .default_options
      .merge(messages: prompt)
      .tap do |b|
        if !stream
          b[:stream] = false
        end
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Ollama do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model) { Fabricate(:ollama_model) }

  let(:ollama_mock) { OllamaMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Ollama, user)
  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      it "completes a trivial prompt and logs the response" do
        compliance.regular_mode_simple_prompt(ollama_mock)
      end
    end
  end

  describe "when using streaming mode" do
    context "with simpel prompts" do
      it "completes a trivial prompt and logs the response" do
        compliance.streaming_mode_simple_prompt(ollama_mock)
      end
    end
  end
end
