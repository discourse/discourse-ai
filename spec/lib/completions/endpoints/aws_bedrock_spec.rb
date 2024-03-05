# frozen_string_literal: true

require_relative "endpoint_compliance"
require "aws-eventstream"
require "aws-sigv4"

class BedrockMock < EndpointMock
  def response(content)
    {
      completion: content,
      stop: "\n\nHuman:",
      stop_reason: "stop_sequence",
      truncated: false,
      log_id: "12dcc7feafbee4a394e0de9dffde3ac5",
      model: "claude",
      exception: nil,
    }
  end

  def stub_response(prompt, response_content, tool_call: false)
    WebMock
      .stub_request(:post, "#{base_url}/invoke")
      .with(body: model.default_options.merge(prompt: prompt).to_json)
      .to_return(status: 200, body: JSON.dump(response(response_content)))
  end

  def stream_line(delta, finish_reason: nil)
    encoder = Aws::EventStream::Encoder.new

    message =
      Aws::EventStream::Message.new(
        payload:
          StringIO.new(
            {
              bytes:
                Base64.encode64(
                  {
                    completion: delta,
                    stop: finish_reason ? "\n\nHuman:" : nil,
                    stop_reason: finish_reason,
                    truncated: false,
                    log_id: "12b029451c6d18094d868bc04ce83f63",
                    model: "claude-2.1",
                    exception: nil,
                  }.to_json,
                ),
            }.to_json,
          ),
      )

    encoder.encode(message)
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

    WebMock
      .stub_request(:post, "#{base_url}/invoke-with-response-stream")
      .with(body: model.default_options.merge(prompt: prompt).to_json)
      .to_return(status: 200, body: chunks)
  end

  def base_url
    "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/anthropic.claude-v2:1"
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  subject(:endpoint) { described_class.new("claude-2", DiscourseAi::Tokenizer::AnthropicTokenizer) }

  fab!(:user)

  let(:bedrock_mock) { BedrockMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Claude, user)
  end

  before do
    SiteSetting.ai_bedrock_access_key_id = "123456"
    SiteSetting.ai_bedrock_secret_access_key = "asd-asd-asd"
    SiteSetting.ai_bedrock_region = "us-east-1"
  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.regular_mode_simple_prompt(bedrock_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(bedrock_mock)
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(bedrock_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.streaming_mode_tools(bedrock_mock)
        end
      end
    end
  end
end
