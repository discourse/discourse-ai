# frozen_string_literal: true

require_relative "../../support/anthropic_completion_stubs"

RSpec.describe DiscourseAi::Inference::AnthropicCompletions do
  before { SiteSetting.ai_anthropic_api_key = "abc-123" }

  it "can complete a trivial prompt" do
    response_text = "1. Serenity\\n2. Laughter\\n3. Adventure"
    prompt = "Human: write 3 words\n\n"
    user_id = 183
    req_opts = { temperature: 0.5, max_tokens_to_sample: 700 }

    AnthropicCompletionStubs.stub_response(prompt, response_text, req_opts: req_opts)

    completions =
      DiscourseAi::Inference::AnthropicCompletions.perform!(
        prompt,
        "claude-v1",
        temperature: req_opts[:temperature],
        max_tokens: req_opts[:max_tokens_to_sample],
        user_id: user_id,
      )

    expect(completions[:completion]).to eq(response_text)

    expect(AiApiAuditLog.count).to eq(1)
    log = AiApiAuditLog.first

    request_body = { model: "claude-v1", prompt: prompt }.merge(req_opts).to_json
    response_body = AnthropicCompletionStubs.response(response_text).to_json

    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.request_tokens).to eq(6)
    expect(log.response_tokens).to eq(16)
    expect(log.raw_request_payload).to eq(request_body)
    expect(log.raw_response_payload).to eq(response_body)
  end

  it "supports streaming mode" do
    deltas = ["Mount", "ain", " ", "Tree ", "Frog"]
    prompt = "Human: write 3 words\n\n"
    req_opts = { max_tokens_to_sample: 300, stream: true }
    content = +""

    AnthropicCompletionStubs.stub_streamed_response(prompt, deltas, req_opts: req_opts)

    DiscourseAi::Inference::AnthropicCompletions.perform!(
      prompt,
      "claude-v1",
      max_tokens: req_opts[:max_tokens_to_sample],
    ) do |partial, cancel|
      data = partial[:completion]
      content = data if data
      cancel.call if content.split(" ").length == 2
    end

    expect(content).to eq("Mountain Tree ")

    expect(AiApiAuditLog.count).to eq(1)
    log = AiApiAuditLog.first

    request_body = { model: "claude-v1", prompt: prompt }.merge(req_opts).to_json

    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.request_tokens).to eq(6)
    expect(log.response_tokens).to eq(3)
    expect(log.raw_request_payload).to eq(request_body)
    expect(log.raw_response_payload).to be_present
  end
end
