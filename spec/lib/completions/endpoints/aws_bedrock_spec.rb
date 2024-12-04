# frozen_string_literal: true

require_relative "endpoint_compliance"
require "aws-eventstream"
require "aws-sigv4"

class BedrockMock < EndpointMock
end

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model) { Fabricate(:bedrock_model) }
  fab!(:nova_model) { Fabricate(:nova_model) }

  let(:bedrock_mock) { BedrockMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Claude, user)
  end

  def encode_message(message)
    wrapped = { bytes: Base64.encode64(message.to_json) }.to_json
    io = StringIO.new(wrapped)
    aws_message = Aws::EventStream::Message.new(payload: io)
    Aws::EventStream::Encoder.new.encode(aws_message)
  end

  context "Amazon nova support" do
    it "should be able to make a simple request" do
      proxy = DiscourseAi::Completions::Llm.proxy("custom:#{nova_model.id}")

      content = {
        "output" => {
          "message" => {
            "content" => [{ "text" => "it is 2." }],
            "role" => "assistant",
          },
        },
        "stopReason" => "end_turn",
        "usage" => {
          "inputTokens" => 14,
          "outputTokens" => 119,
          "totalTokens" => 133,
          "cacheReadInputTokenCount" => nil,
          "cacheWriteInputTokenCount" => nil,
        },
      }.to_json

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.nova-pro-v1:0/invoke",
      ).to_return(status: 200, body: content)

      response = proxy.generate("hello world", user: user)
      expect(response).to eq("it is 2.")

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(14)
      expect(log.response_tokens).to eq(119)
    end

    it "should be able to make a streaming request" do
      messages =
        [
          { messageStart: { role: "assistant" } },
          { contentBlockDelta: { delta: { text: "Hello" }, contentBlockIndex: 0 } },
          { contentBlockStop: { contentBlockIndex: 0 } },
          { contentBlockDelta: { delta: { text: "!" }, contentBlockIndex: 1 } },
          { contentBlockStop: { contentBlockIndex: 1 } },
          {
            metadata: {
              usage: {
                inputTokens: 14,
                outputTokens: 18,
              },
              metrics: {
              },
              trace: {
              },
            },
            "amazon-bedrock-invocationMetrics": {
              inputTokenCount: 14,
              outputTokenCount: 18,
              invocationLatency: 402,
              firstByteLatency: 72,
            },
          },
        ].map { |message| encode_message(message) }

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.nova-pro-v1:0/invoke-with-response-stream",
      ).to_return(status: 200, body: messages.join)

      proxy = DiscourseAi::Completions::Llm.proxy("custom:#{nova_model.id}")
      responses = []
      proxy.generate("Hello!", user: user) { |partial| responses << partial }

      expect(responses).to eq(%w[Hello !])
      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(14)
      expect(log.response_tokens).to eq(18)
    end
  end

  it "should provide accurate max token count" do
    prompt = DiscourseAi::Completions::Prompt.new("hello")
    dialect = DiscourseAi::Completions::Dialects::Claude.new(prompt, model)
    endpoint = DiscourseAi::Completions::Endpoints::AwsBedrock.new(model)

    model.name = "claude-2"
    expect(endpoint.default_options(dialect)[:max_tokens]).to eq(4096)

    model.name = "claude-3-5-sonnet"
    expect(endpoint.default_options(dialect)[:max_tokens]).to eq(8192)

    model.name = "claude-3-5-haiku"
    options = endpoint.default_options(dialect)
    expect(options[:max_tokens]).to eq(8192)
  end

  describe "function calling" do
    it "supports old school xml function calls" do
      model.provider_params["disable_native_tools"] = true
      model.save!

      proxy = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      incomplete_tool_call = <<~XML.strip
        <thinking>I should be ignored</thinking>
        <search_quality_reflection>also ignored</search_quality_reflection>
        <search_quality_score>0</search_quality_score>
        <function_calls>
        <invoke>
        <tool_name>google</tool_name>
        <parameters><query>sydney weather today</query></parameters>
        </invoke>
        </function_calls>
      XML

      messages =
        [
          { type: "message_start", message: { usage: { input_tokens: 9 } } },
          { type: "content_block_delta", delta: { text: "hello\n" } },
          { type: "content_block_delta", delta: { text: incomplete_tool_call } },
          { type: "message_delta", delta: { usage: { output_tokens: 25 } } },
        ].map { |message| encode_message(message) }

      request = nil
      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        prompt =
          DiscourseAi::Completions::Prompt.new(
            messages: [{ type: :user, content: "what is the weather in sydney" }],
          )

        tool = {
          name: "google",
          description: "Will search using Google",
          parameters: [
            { name: "query", description: "The search query", type: "string", required: true },
          ],
        }

        prompt.tools = [tool]
        response = []
        proxy.generate(prompt, user: user) { |partial| response << partial }

        expect(request.headers["Authorization"]).to be_present
        expect(request.headers["X-Amz-Content-Sha256"]).to be_present

        parsed_body = JSON.parse(request.body)
        expect(parsed_body["system"]).to include("<function_calls>")
        expect(parsed_body["tools"]).to eq(nil)
        expect(parsed_body["stop_sequences"]).to eq(["</function_calls>"])

        expected = [
          "hello\n",
          DiscourseAi::Completions::ToolCall.new(
            id: "tool_0",
            name: "google",
            parameters: {
              query: "sydney weather today",
            },
          ),
        ]

        expect(response).to eq(expected)
      end
    end

    it "supports streaming function calls" do
      proxy = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      request = nil

      messages =
        [
          {
            type: "message_start",
            message: {
              id: "msg_bdrk_01WYxeNMk6EKn9s98r6XXrAB",
              type: "message",
              role: "assistant",
              model: "claude-3-sonnet-20240307",
              stop_sequence: nil,
              usage: {
                input_tokens: 840,
                output_tokens: 1,
              },
              content: [],
              stop_reason: nil,
            },
          },
          {
            type: "content_block_start",
            index: 0,
            delta: {
              text: "<thinking>I should be ignored</thinking>",
            },
          },
          {
            type: "content_block_start",
            index: 0,
            content_block: {
              type: "tool_use",
              id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7",
              name: "google",
              input: {
              },
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "",
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "{\"query\": \"s",
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "ydney weat",
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "her today\"}",
            },
          },
          { type: "content_block_stop", index: 0 },
          {
            type: "message_delta",
            delta: {
              stop_reason: "tool_use",
              stop_sequence: nil,
            },
            usage: {
              output_tokens: 53,
            },
          },
          {
            type: "message_stop",
            "amazon-bedrock-invocationMetrics": {
              inputTokenCount: 846,
              outputTokenCount: 39,
              invocationLatency: 880,
              firstByteLatency: 402,
            },
          },
        ].map { |message| encode_message(message) }

      messages = messages.join("").split

      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        prompt =
          DiscourseAi::Completions::Prompt.new(
            messages: [{ type: :user, content: "what is the weather in sydney" }],
          )

        tool = {
          name: "google",
          description: "Will search using Google",
          parameters: [
            { name: "query", description: "The search query", type: "string", required: true },
          ],
        }

        prompt.tools = [tool]
        response = []
        proxy.generate(prompt, user: user) { |partial| response << partial }

        expect(request.headers["Authorization"]).to be_present
        expect(request.headers["X-Amz-Content-Sha256"]).to be_present

        expected_response = [
          DiscourseAi::Completions::ToolCall.new(
            id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7",
            name: "google",
            parameters: {
              query: "sydney weather today",
            },
          ),
        ]

        expect(response).to eq(expected_response)

        expected = {
          "max_tokens" => 4096,
          "anthropic_version" => "bedrock-2023-05-31",
          "messages" => [{ "role" => "user", "content" => "what is the weather in sydney" }],
          "tools" => [
            {
              "name" => "google",
              "description" => "Will search using Google",
              "input_schema" => {
                "type" => "object",
                "properties" => {
                  "query" => {
                    "type" => "string",
                    "description" => "The search query",
                  },
                },
                "required" => ["query"],
              },
            },
          ],
        }
        expect(JSON.parse(request.body)).to eq(expected)

        log = AiApiAuditLog.order(:id).last
        expect(log.request_tokens).to eq(846)
        expect(log.response_tokens).to eq(39)
      end
    end
  end

  describe "Claude 3 support" do
    it "supports regular completions" do
      proxy = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      request = nil

      content = {
        content: [text: "hello sam"],
        usage: {
          input_tokens: 10,
          output_tokens: 20,
        },
      }.to_json

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke",
      )
        .with do |inner_request|
          request = inner_request
          true
        end
        .to_return(status: 200, body: content)

      response = proxy.generate("hello world", user: user)

      expect(request.headers["Authorization"]).to be_present
      expect(request.headers["X-Amz-Content-Sha256"]).to be_present

      expected = {
        "max_tokens" => 4096,
        "anthropic_version" => "bedrock-2023-05-31",
        "messages" => [{ "role" => "user", "content" => "hello world" }],
        "system" => "You are a helpful bot",
      }
      expect(JSON.parse(request.body)).to eq(expected)

      expect(response).to eq("hello sam")

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(10)
      expect(log.response_tokens).to eq(20)
    end

    it "supports claude 3 streaming" do
      proxy = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      request = nil

      messages =
        [
          { type: "message_start", message: { usage: { input_tokens: 9 } } },
          { type: "content_block_delta", delta: { text: "hello " } },
          { type: "content_block_delta", delta: { text: "sam" } },
          { type: "message_delta", delta: { usage: { output_tokens: 25 } } },
        ].map { |message| encode_message(message) }

      # stream 1 letter at a time
      # cause we need to handle this case
      messages = messages.join("").split

      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        response = +""
        proxy.generate("hello world", user: user) { |partial| response << partial }

        expect(request.headers["Authorization"]).to be_present
        expect(request.headers["X-Amz-Content-Sha256"]).to be_present

        expected = {
          "max_tokens" => 4096,
          "anthropic_version" => "bedrock-2023-05-31",
          "messages" => [{ "role" => "user", "content" => "hello world" }],
          "system" => "You are a helpful bot",
        }
        expect(JSON.parse(request.body)).to eq(expected)

        expect(response).to eq("hello sam")

        log = AiApiAuditLog.order(:id).last
        expect(log.request_tokens).to eq(9)
        expect(log.response_tokens).to eq(25)
      end
    end
  end
end
