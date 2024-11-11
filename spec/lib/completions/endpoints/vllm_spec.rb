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
      .stub_request(:post, "https://test.dev/v1/chat/completions")
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
      .stub_request(:post, "https://test.dev/v1/chat/completions")
      .with(body: model.default_options.merge(messages: prompt, stream: true).to_json)
      .to_return(status: 200, body: chunks)
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Vllm do
  subject(:endpoint) { described_class.new(llm_model) }

  fab!(:llm_model) { Fabricate(:vllm_model) }
  fab!(:user)

  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  let(:vllm_mock) { VllmMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(
      self,
      endpoint,
      DiscourseAi::Completions::Dialects::OpenAiCompatible,
      user,
    )
  end

  let(:dialect) do
    DiscourseAi::Completions::Dialects::OpenAiCompatible.new(generic_prompt, llm_model)
  end
  let(:prompt) { dialect.translate }

  let(:request_body) { model.default_options.merge(messages: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(messages: prompt, stream: true).to_json }

  describe "tool support" do
    it "is able to invoke XML tools correctly" do
      xml = <<~XML
        <function_calls>
        <invoke>
        <tool_name>calculate</tool_name>
        <parameters>
        <expression>1+1</expression></parameters>
        </invoke>
        </function_calls>
        should be ignored
      XML

      body = {
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
          { message: { role: "assistant", content: xml }, finish_reason: "stop", index: 0 },
        ],
      }
      tool = {
        name: "calculate",
        description: "calculate something",
        parameters: [
          {
            name: "expression",
            type: "string",
            description: "expression to calculate",
            required: true,
          },
        ],
      }

      stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
        status: 200,
        body: body.to_json,
      )

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You a calculator",
          messages: [{ type: :user, id: "user1", content: "calculate 2758975 + 21.11" }],
          tools: [tool],
        )

      result = llm.generate(prompt, user: Discourse.system_user)

      expected = DiscourseAi::Completions::ToolCall.new(
        name: "calculate",
        id: "tool_0",
        parameters: { expression: "1+1" },
      )

      expect(result).to eq(expected)
    end
  end

  it "correctly accounts for tokens in non streaming mode" do
    body = (<<~TEXT).strip
      {"id":"chat-c580e4a9ebaa44a0becc802ed5dc213a","object":"chat.completion","created":1731294404,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"message":{"role":"assistant","content":"Random Number Generator Produces Smallest Possible Result","tool_calls":[]},"logprobs":null,"finish_reason":"stop","stop_reason":null}],"usage":{"prompt_tokens":146,"total_tokens":156,"completion_tokens":10},"prompt_logprobs":null}
    TEXT

    stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
      status: 200,
      body: body,
    )

    result = llm.generate("generate a title", user: Discourse.system_user)

    expect(result).to eq("Random Number Generator Produces Smallest Possible Result")

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(146)
    expect(log.response_tokens).to eq(10)

  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(vllm_mock)
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(vllm_mock)
        end
      end

      context "with tools" do
        it "returns a function invoncation" do
          compliance.streaming_mode_tools(vllm_mock)
        end
      end
    end
  end
end
