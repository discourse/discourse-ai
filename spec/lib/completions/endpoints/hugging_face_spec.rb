# frozen_string_literal: true

require_relative "endpoint_compliance"

class HuggingFaceMock < EndpointMock
  def response(content)
    [{ generated_text: content }]
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "#{SiteSetting.ai_hugging_face_api_url}")
      .with(body: request_body(prompt))
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, deltas, finish_reason: nil)
    +"data: " << {
      token: {
        id: 29_889,
        text: delta,
        logprob: -0.08319092,
        special: !!finish_reason,
      },
      generated_text: finish_reason ? deltas.join : nil,
      details: nil,
    }.to_json
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], deltas, finish_reason: true)
        else
          stream_line(deltas[index], deltas)
        end
      end

    chunks = (chunks.join("\n\n") << "data: [DONE]").split("")

    WebMock
      .stub_request(:post, "#{SiteSetting.ai_hugging_face_api_url}")
      .with(body: request_body(prompt, stream: true))
      .to_return(status: 200, body: chunks)
  end

  def request_body(prompt, stream: false)
    model
      .default_options
      .merge(inputs: prompt)
      .tap do |payload|
        payload[:parameters][:max_new_tokens] = (SiteSetting.ai_hugging_face_token_limit || 4_000) -
          model.prompt_size(prompt)
        payload[:stream] = true if stream
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::HuggingFace do
  subject(:endpoint) do
    described_class.new("Llama2-*-chat-hf", DiscourseAi::Tokenizer::Llama2Tokenizer)
  end

  before { SiteSetting.ai_hugging_face_api_url = "https://test.dev" }

  fab!(:user) { Fabricate(:user) }

  let(:hf_mock) { HuggingFaceMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Llama2Classic, user)
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
