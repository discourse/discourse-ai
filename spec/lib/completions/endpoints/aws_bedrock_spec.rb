# frozen_string_literal: true

require_relative "endpoint_examples"
require "aws-eventstream"
require "aws-sigv4"

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::AnthropicTokenizer) }

  let(:model_name) { "claude-2" }
  let(:bedrock_name) { "claude-v2:1" }
  let(:generic_prompt) { { insts: "write 3 words" } }
  let(:dialect) { DiscourseAi::Completions::Dialects::Claude.new(generic_prompt, model_name) }
  let(:prompt) { dialect.translate }

  let(:request_body) { model.default_options.merge(prompt: prompt).to_json }
  let(:stream_request_body) { request_body }

  let(:tool_id) { "get_weather" }

  before do
    SiteSetting.ai_bedrock_access_key_id = "123456"
    SiteSetting.ai_bedrock_secret_access_key = "asd-asd-asd"
    SiteSetting.ai_bedrock_region = "us-east-1"
  end

  def response(content)
    {
      completion: content,
      stop: "\n\nHuman:",
      stop_reason: "stop_sequence",
      truncated: false,
      log_id: "12dcc7feafbee4a394e0de9dffde3ac5",
      model: model_name,
      exception: nil,
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(
        :post,
        "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/anthropic.#{bedrock_name}/invoke",
      )
      .with(body: request_body)
      .to_return(status: 200, body: JSON.dump(response(response_text)))
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
      .stub_request(
        :post,
        "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/anthropic.#{bedrock_name}/invoke-with-response-stream",
      )
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  let(:tool_deltas) { ["<function", <<~REPLY] }
  _calls>
  <invoke>
  <tool_name>get_weather</tool_name>
  <parameters>
  <location>Sydney</location>
  <unit>c</unit>
  </parameters>
  </invoke>
  </function_calls>
  REPLY

  let(:tool_call) { invocation }

  it_behaves_like "an endpoint that can communicate with a completion service"
end
