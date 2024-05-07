# frozen_string_literal: true

require_relative "endpoint_compliance"

class VllmMock < EndpointMock
  def response(content)
    {
      id: "cmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
      object: "chat.completion",
      created: 1_678_464_820,
      model: "mistralai/Mixtral-8x7B-Instruct-v0.1",
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
      .stub_request(:post, "#{SiteSetting.ai_vllm_endpoint}/v1/chat/completions")
      .with(body: model.default_options.merge(messages: prompt).to_json)
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    +"data: " << {
      id: "cmpl-#{SecureRandom.hex}",
      created: 1_681_283_881,
      model: "mistralai/Mixtral-8x7B-Instruct-v0.1",
      choices: [{ delta: { content: delta } }],
      index: 0,
    }.to_json
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
      .stub_request(:post, "#{SiteSetting.ai_vllm_endpoint}/v1/chat/completions")
      .with(body: model.default_options.merge(messages: prompt, stream: true).to_json)
      .to_return(status: 200, body: chunks)
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Vllm do
  subject(:endpoint) do
    described_class.new(
      "mistralai/Mixtral-8x7B-Instruct-v0.1",
      DiscourseAi::Tokenizer::MixtralTokenizer,
    )
  end

  fab!(:user)

  let(:anthropic_mock) { VllmMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Mistral, user)
  end

  let(:dialect) { DiscourseAi::Completions::Dialects::Mistral.new(generic_prompt, model_name) }
  let(:prompt) { dialect.translate }

  let(:request_body) { model.default_options.merge(messages: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(messages: prompt, stream: true).to_json }

  before { SiteSetting.ai_vllm_endpoint = "https://test.dev" }

  describe "#perform_completion!" do
    context "when using regular mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.regular_mode_simple_prompt(anthropic_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(anthropic_mock)
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(anthropic_mock)
        end
      end

      context "with tools" do
        it "returns a function invoncation" do
          compliance.streaming_mode_tools(anthropic_mock)
        end
      end
    end
  end
end
