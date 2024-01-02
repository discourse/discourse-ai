# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::Vllm do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::MixtralTokenizer) }

  let(:model_name) { "mistralai/Mixtral-8x7B-Instruct-v0.1" }
  let(:generic_prompt) { { insts: "You are a helpful bot.", input: "write 3 words" } }
  let(:dialect) { DiscourseAi::Completions::Dialects::Mixtral.new(generic_prompt, model_name) }
  let(:prompt) { dialect.translate }

  let(:request_body) { model.default_options.merge(prompt: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(prompt: prompt, stream: true).to_json }

  before { SiteSetting.ai_vllm_endpoint = "https://test.dev" }

  let(:tool_id) { "get_weather" }

  def response(content)
    {
      id: "cmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
      object: "text_completion",
      created: 1_678_464_820,
      model: model_name,
      usage: {
        prompt_tokens: 337,
        completion_tokens: 162,
        total_tokens: 499,
      },
      choices: [{ text: content, finish_reason: "stop", index: 0 }],
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "#{SiteSetting.ai_vllm_endpoint}/v1/completions")
      .with(body: request_body)
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    +"data: " << {
      id: "cmpl-#{SecureRandom.hex}",
      created: 1_681_283_881,
      model: model_name,
      choices: [{ text: delta, finish_reason: finish_reason, index: 0 }],
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
      .stub_request(:post, "#{SiteSetting.ai_vllm_endpoint}/v1/completions")
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  let(:tool_deltas) { ["<function", <<~REPLY, <<~REPLY] }
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
      <function_calls>
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
