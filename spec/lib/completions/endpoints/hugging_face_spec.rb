# frozen_string_literal: true

require_relative "endpoint_compliance"

class HuggingFaceMock < EndpointMock
  def response(content)
    {
      id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
      object: "chat.completion",
      created: 1_678_464_820,
      model: "Llama2-*-chat-hf",
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

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "#{SiteSetting.ai_hugging_face_api_url}")
      .with(body: request_body(prompt))
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    +"data: " << {
      id: "chatcmpl-#{SecureRandom.hex}",
      object: "chat.completion.chunk",
      created: 1_681_283_881,
      model: "Llama2-*-chat-hf",
      choices: [{ delta: { content: delta } }],
      finish_reason: finish_reason,
      index: 0,
    }.to_json
  end

  def stub_raw(chunks)
    WebMock.stub_request(:post, "#{SiteSetting.ai_hugging_face_api_url}").to_return(
      status: 200,
      body: chunks,
    )
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "stop_sequence")
        else
          stream_line(deltas[index])
        end
      end

    chunks = (chunks.join("\n\n") << "data: [DONE]").split("")

    WebMock
      .stub_request(:post, "#{SiteSetting.ai_hugging_face_api_url}")
      .with(body: request_body(prompt, stream: true))
      .to_return(status: 200, body: chunks)

    yield if block_given?
  end

  def request_body(prompt, stream: false, tool_call: false)
    model
      .default_options
      .merge(messages: prompt)
      .tap do |b|
        b[:max_tokens] = (SiteSetting.ai_hugging_face_token_limit || 4_000) -
          model.prompt_size(prompt)
        b[:stream] = true if stream
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::HuggingFace do
  subject(:endpoint) do
    described_class.new(
      "mistralai/Mistral-7B-Instruct-v0.2",
      DiscourseAi::Tokenizer::MixtralTokenizer,
    )
  end

  before { SiteSetting.ai_hugging_face_api_url = "https://test.dev" }

  fab!(:user)

  let(:hf_mock) { HuggingFaceMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Mistral, user)
  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.regular_mode_simple_prompt(hf_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(hf_mock)
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(hf_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.streaming_mode_tools(hf_mock)
        end
      end
    end
  end
end
