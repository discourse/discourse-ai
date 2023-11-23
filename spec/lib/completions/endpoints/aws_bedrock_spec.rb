# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::AnthropicTokenizer) }

  let(:model_name) { "claude-2" }
  let(:prompt) { "Human: write 3 words\n\n" }

  let(:request_body) { model.default_options.merge(prompt: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(prompt: prompt).to_json }

  before do
    SiteSetting.ai_bedrock_access_key_id = "123456"
    SiteSetting.ai_bedrock_secret_access_key = "asd-asd-asd"
    SiteSetting.ai_bedrock_region = "us-east-1"
  end

  # Copied from https://github.com/bblimke/webmock/issues/629
  # Workaround for stubbing a streamed response
  before do
    mocked_http =
      Class.new(Net::HTTP) do
        def request(*)
          super do |response|
            response.instance_eval do
              def read_body(*, &block)
                if block_given?
                  @body.each(&block)
                else
                  super
                end
              end
            end

            yield response if block_given?

            response
          end
        end
      end

    @original_net_http = Net.send(:remove_const, :HTTP)
    Net.send(:const_set, :HTTP, mocked_http)
  end

  after do
    Net.send(:remove_const, :HTTP)
    Net.send(:const_set, :HTTP, @original_net_http)
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

  def stub_response(prompt, response_text)
    WebMock
      .stub_request(
        :post,
        "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/anthropic.#{model_name}/invoke",
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
                    model: "claude-2",
                    exception: nil,
                  }.to_json,
                ),
            }.to_json,
          ),
      )

    encoder.encode(message)
  end

  def stub_streamed_response(prompt, deltas)
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
        "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/anthropic.#{model_name}/invoke-with-response-stream",
      )
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  it_behaves_like "an endpoint that can communicate with a completion service"
end
