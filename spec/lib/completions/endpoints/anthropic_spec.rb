# frozen_String_literal: true

require_relative "endpoint_compliance"

class AnthropicMock < EndpointMock
  def response(content)
    {
      completion: content,
      stop: "\n\nHuman:",
      stop_reason: "stop_sequence",
      truncated: false,
      log_id: "12dcc7feafbee4a394e0de9dffde3ac5",
      model: "claude-2",
      exception: nil,
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "https://api.anthropic.com/v1/complete")
      .with(body: model.default_options.merge(prompt: prompt).to_json)
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    +"data: " << {
      completion: delta,
      stop: finish_reason ? "\n\nHuman:" : nil,
      stop_reason: finish_reason,
      truncated: false,
      log_id: "12b029451c6d18094d868bc04ce83f63",
      model: "claude-2",
      exception: nil,
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

    chunks = chunks.join("\n\n").split("")

    WebMock
      .stub_request(:post, "https://api.anthropic.com/v1/complete")
      .with(body: model.default_options.merge(prompt: prompt, stream: true).to_json)
      .to_return(status: 200, body: chunks)
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Anthropic do
  subject(:endpoint) { described_class.new("claude-2", DiscourseAi::Tokenizer::AnthropicTokenizer) }

  fab!(:user) { Fabricate(:user) }

  let(:anthropic_mock) { AnthropicMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Claude, user)
  end

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
        it "returns a function invocation" do
          compliance.streaming_mode_tools(anthropic_mock)
        end
      end
    end
  end
end
