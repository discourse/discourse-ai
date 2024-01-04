# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAi do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::OpenAiTokenizer) }

  let(:model_name) { "gpt-3.5-turbo" }
  let(:generic_prompt) { { insts: "You are a helpful bot.", input: "write 3 words" } }
  let(:dialect) { DiscourseAi::Completions::Dialects::ChatGpt.new(generic_prompt, model_name) }
  let(:prompt) { dialect.translate }

  let(:tool_id) { "eujbuebfe" }

  let(:tool_deltas) do
    [
      { id: tool_id, function: {} },
      { id: tool_id, function: { name: "get_weather", arguments: "" } },
      { id: tool_id, function: { name: "get_weather", arguments: "" } },
      { id: tool_id, function: { name: "get_weather", arguments: "{" } },
      { id: tool_id, function: { name: "get_weather", arguments: " \"location\": \"Sydney\"" } },
      { id: tool_id, function: { name: "get_weather", arguments: " ,\"unit\": \"c\" }" } },
    ]
  end

  let(:tool_call) do
    {
      id: tool_id,
      function: {
        name: "get_weather",
        arguments: { location: "Sydney", unit: "c" }.to_json,
      },
    }
  end

  let(:request_body) do
    model
      .default_options
      .merge(messages: prompt)
      .tap { |b| b[:tools] = dialect.tools if generic_prompt[:tools] }
      .to_json
  end

  let(:stream_request_body) do
    model
      .default_options
      .merge(messages: prompt, stream: true)
      .tap { |b| b[:tools] = dialect.tools if generic_prompt[:tools] }
      .to_json
  end

  def response(content, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [content] }
      else
        { content: content }
      end

    {
      id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
      object: "chat.completion",
      created: 1_678_464_820,
      model: "gpt-3.5-turbo-0301",
      usage: {
        prompt_tokens: 337,
        completion_tokens: 162,
        total_tokens: 499,
      },
      choices: [
        { message: { role: "assistant" }.merge(message_content), finish_reason: "stop", index: 0 },
      ],
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: request_body)
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta, finish_reason: nil, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [delta] }
      else
        { content: delta }
      end

    +"data: " << {
      id: "chatcmpl-#{SecureRandom.hex}",
      object: "chat.completion.chunk",
      created: 1_681_283_881,
      model: "gpt-3.5-turbo-0301",
      choices: [{ delta: message_content }],
      finish_reason: finish_reason,
      index: 0,
    }.to_json
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "stop_sequence", tool_call: tool_call)
        else
          stream_line(deltas[index], tool_call: tool_call)
        end
      end

    chunks = (chunks.join("\n\n") << "data: [DONE]").split("")

    WebMock
      .stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  it_behaves_like "an endpoint that can communicate with a completion service"

  context "when chunked encoding returns partial chunks" do
    # See: https://github.com/bblimke/webmock/issues/629
    let(:mock_net_http) do
      Class.new(Net::HTTP) do
        def request(*)
          super do |response|
            response.instance_eval do
              def read_body(*, &)
                @body.each(&)
              end
            end

            yield response if block_given?

            response
          end
        end
      end
    end

    let(:remove_original_net_http) { Net.send(:remove_const, :HTTP) }
    let(:original_http) { remove_original_net_http }
    let(:stub_net_http) { Net.send(:const_set, :HTTP, mock_net_http) }

    let(:remove_stubbed_net_http) { Net.send(:remove_const, :HTTP) }
    let(:restore_net_http) { Net.send(:const_set, :HTTP, original_http) }

    before do
      mock_net_http
      remove_original_net_http
      stub_net_http
    end

    after do
      remove_stubbed_net_http
      restore_net_http
    end

    it "will automatically recover from a bad payload" do
      # this should not happen, but lets ensure nothing bad happens
      # the row with test1 is invalid json
      raw_data = <<~TEXT
d|a|t|a|:| |{|"choices":[{"delta":{"content":"test,"}}]}

data: {"choices":[{"delta":{"content":"test1,"}}]

data: {"choices":[{"delta":|{"content":"test2,"}}]}

data: {"choices":[{"delta":{"content":"test3,"}}]|}

data: {"choices":[{|"|d|elta":{"content":"test4"}}]|}

data: [D|ONE]
    TEXT

      chunks = raw_data.split("|")

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: chunks,
      )

      partials = []
      llm = DiscourseAi::Completions::Llm.proxy("gpt-3.5-turbo")
      llm.generate({ insts: "test" }, user: Discourse.system_user) { |partial| partials << partial }

      expect(partials.join).to eq("test,test2,test3,test4")
    end

    it "supports chunked encoding properly" do
      raw_data = <<~TEXT
da|ta: {"choices":[{"delta":{"content":"test,"}}]}

data: {"choices":[{"delta":{"content":"test1,"}}]}

data: {"choices":[{"delta":|{"content":"test2,"}}]}

data: {"choices":[{"delta":{"content":"test3,"}}]|}

data: {"choices":[{|"|d|elta":{"content":"test4"}}]|}

data: [D|ONE]
    TEXT

      chunks = raw_data.split("|")

      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: chunks,
      )

      partials = []
      llm = DiscourseAi::Completions::Llm.proxy("gpt-3.5-turbo")
      llm.generate({ insts: "test" }, user: Discourse.system_user) { |partial| partials << partial }

      expect(partials.join).to eq("test,test1,test2,test3,test4")
    end
  end
end
