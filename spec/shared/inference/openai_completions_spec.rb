# frozen_string_literal: true
require "rails_helper"

require_relative "../../support/openai_completions_inference_stubs"

describe DiscourseAi::Inference::OpenAiCompletions do
  before { SiteSetting.ai_openai_api_key = "abc-123" }

  it "can complete a trivial prompt" do
    response_text = "1. Serenity\\n2. Laughter\\n3. Adventure"
    prompt = [role: "user", content: "write 3 words"]
    user_id = 183
    req_opts = { temperature: 0.5, top_p: 0.8, max_tokens: 700 }

    OpenAiCompletionsInferenceStubs.stub_response(prompt, response_text, req_opts: req_opts)

    completions =
      DiscourseAi::Inference::OpenAiCompletions.perform!(
        prompt,
        "gpt-3.5-turbo",
        temperature: 0.5,
        top_p: 0.8,
        max_tokens: 700,
        user_id: user_id,
      )

    expect(completions.dig(:choices, 0, :message, :content)).to eq(response_text)

    expect(AiApiAuditLog.count).to eq(1)
    log = AiApiAuditLog.first

    body = { model: "gpt-3.5-turbo", messages: prompt }.merge(req_opts).to_json
    request_body = OpenAiCompletionsInferenceStubs.response(response_text).to_json

    expect(log.provider_id).to eq(AiApiAuditLog::Provider::OpenAI)
    expect(log.request_tokens).to eq(337)
    expect(log.response_tokens).to eq(162)
    expect(log.raw_request_payload).to eq(body)
    expect(log.raw_response_payload).to eq(request_body)
  end

  it "can operate in streaming mode" do
    deltas = [
      { role: "assistant" },
      { content: "Mount" },
      { content: "ain" },
      { content: " " },
      { content: "Tree " },
      { content: "Frog" },
    ]

    prompt = [role: "user", content: "write 3 words"]
    content = +""

    OpenAiCompletionsInferenceStubs.stub_streamed_response(
      prompt,
      deltas,
      req_opts: {
        stream: true,
      },
    )

    DiscourseAi::Inference::OpenAiCompletions.perform!(prompt, "gpt-3.5-turbo") do |partial, cancel|
      data = partial.dig(:choices, 0, :delta, :content)
      content << data if data
      cancel.call if content.split(" ").length == 2
    end

    expect(content).to eq("Mountain Tree ")

    expect(AiApiAuditLog.count).to eq(1)
    log = AiApiAuditLog.first

    request_body = { model: "gpt-3.5-turbo", messages: prompt, stream: true }.to_json

    expect(log.provider_id).to eq(AiApiAuditLog::Provider::OpenAI)
    expect(log.request_tokens).to eq(5)
    expect(log.response_tokens).to eq(4)
    expect(log.raw_request_payload).to eq(request_body)
    expect(log.raw_response_payload).to be_present
  end
end
