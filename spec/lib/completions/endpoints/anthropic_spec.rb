# frozen_String_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::Anthropic do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::AnthropicTokenizer) }

  let(:model_name) { "claude-2" }
  let(:generic_prompt) { { insts: "write 3 words" } }
  let(:dialect) { DiscourseAi::Completions::Dialects::Claude.new(generic_prompt, model_name) }
  let(:prompt) { dialect.translate }

  let(:request_body) { model.default_options.merge(prompt: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(prompt: prompt, stream: true).to_json }

  let(:tool_id) { "get_weather" }

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
      .stub_request(:post, "https://api.anthropic.com/v1/complete")
      .with(body: request_body)
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
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  let(:tool_deltas) { ["Let me use a tool for that<function", <<~REPLY] }
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
