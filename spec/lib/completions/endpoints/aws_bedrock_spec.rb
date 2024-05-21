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
