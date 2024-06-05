# frozen_string_literal: true

require_relative "endpoint_compliance"
require "aws-eventstream"
require "aws-sigv4"

class BedrockMock < EndpointMock
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

  describe "function calling" do
    it "supports streaming function calls" do
      proxy = DiscourseAi::Completions::Llm.proxy("aws_bedrock:claude-3-sonnet")

      request = nil

      messages =
        [
          {
            type: "message_start",
            message: {
              id: "msg_bdrk_01WYxeNMk6EKn9s98r6XXrAB",
              type: "message",
              role: "assistant",
              model: "claude-3-haiku-20240307",
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
        ].map do |message|
          wrapped = { bytes: Base64.encode64(message.to_json) }.to_json
          io = StringIO.new(wrapped)
          aws_message = Aws::EventStream::Message.new(payload: io)
          Aws::EventStream::Encoder.new.encode(aws_message)
        end

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
        response = +""
        proxy.generate(prompt, user: user) { |partial| response << partial }

        expect(request.headers["Authorization"]).to be_present
        expect(request.headers["X-Amz-Content-Sha256"]).to be_present

        expected_response = (<<~RESPONSE).strip
        <function_calls>
        <invoke>
        <tool_name>google</tool_name>
        <parameters><query>sydney weather today</query></parameters>
        <tool_id>toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7</tool_id>
        </invoke>
        </function_calls>
        RESPONSE

        expect(response.strip).to eq(expected_response)

        expected = {
          "max_tokens" => 3000,
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

  describe "Claude 3 Sonnet support" do
    it "supports the sonnet model" do
      proxy = DiscourseAi::Completions::Llm.proxy("aws_bedrock:claude-3-sonnet")

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
        "max_tokens" => 3000,
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

    it "supports claude 3 sonnet streaming" do
      proxy = DiscourseAi::Completions::Llm.proxy("aws_bedrock:claude-3-sonnet")

      request = nil

      messages =
        [
          { type: "message_start", message: { usage: { input_tokens: 9 } } },
          { type: "content_block_delta", delta: { text: "hello " } },
          { type: "content_block_delta", delta: { text: "sam" } },
          { type: "message_delta", delta: { usage: { output_tokens: 25 } } },
        ].map do |message|
          wrapped = { bytes: Base64.encode64(message.to_json) }.to_json
          io = StringIO.new(wrapped)
          aws_message = Aws::EventStream::Message.new(payload: io)
          Aws::EventStream::Encoder.new.encode(aws_message)
        end

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
          "max_tokens" => 3000,
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
