# frozen_string_literal: true
require "rails_helper"

describe DiscourseAi::Inference::OpenAiCompletions do
  before { SiteSetting.ai_openai_api_key = "abc-123" }

  it "can complete a trivial prompt" do
    body = <<~JSON
      {"id":"chatcmpl-74OT0yKnvbmTkqyBINbHgAW0fpbxc","object":"chat.completion","created":1681281718,"model":"gpt-3.5-turbo-0301","usage":{"prompt_tokens":12,"completion_tokens":13,"total_tokens":25},"choices":[{"message":{"role":"assistant","content":"1. Serenity\\n2. Laughter\\n3. Adventure"},"finish_reason":"stop","index":0}]}
    JSON

    stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
      body:
        "{\"model\":\"gpt-3.5-turbo\",\"messages\":[{\"role\":\"user\",\"content\":\"write 3 words\"}],\"temperature\":0.5,\"top_p\":0.8,\"max_tokens\":700}",
      headers: {
        "Authorization" => "Bearer #{SiteSetting.ai_openai_api_key}",
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: body, headers: {})

    prompt = [role: "user", content: "write 3 words"]
    completions =
      DiscourseAi::Inference::OpenAiCompletions.perform!(
        prompt,
        "gpt-3.5-turbo",
        temperature: 0.5,
        top_p: 0.8,
        max_tokens: 700,
      )
    expect(completions[:choices][0][:message][:content]).to eq(
      "1. Serenity\n2. Laughter\n3. Adventure",
    )
  end

  it "raises an error if attempting to stream without a block" do
    expect do
      DiscourseAi::Inference::OpenAiCompletions.perform!([], "gpt-3.5-turbo", stream: true)
    end.to raise_error(ArgumentError)
  end

  def stream_line(finish_reason: nil, delta: {})
    +"data: " << {
      id: "chatcmpl-#{SecureRandom.hex}",
      object: "chat.completion.chunk",
      created: 1_681_283_881,
      model: "gpt-3.5-turbo-0301",
      choices: [{ delta: delta }],
      finish_reason: finish_reason,
      index: 0,
    }.to_json
  end

  it "can operate in streaming mode" do
    payload = [
      stream_line(delta: { role: "assistant" }),
      stream_line(delta: { content: "Mount" }),
      stream_line(delta: { content: "ain" }),
      stream_line(delta: { content: " " }),
      stream_line(delta: { content: "Tree " }),
      stream_line(delta: { content: "Frog" }),
      stream_line(finish_reason: "stop"),
      "[DONE]",
    ].join("\n\n")

    stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
      body:
        "{\"model\":\"gpt-3.5-turbo\",\"messages\":[{\"role\":\"user\",\"content\":\"write 3 words\"}],\"stream\":true}",
      headers: {
        "Accept" => "*/*",
        "Authorization" => "Bearer abc-123",
        "Content-Type" => "application/json",
        "Host" => "api.openai.com",
      },
    ).to_return(status: 200, body: payload, headers: {})

    prompt = [role: "user", content: "write 3 words"]

    content = +""

    DiscourseAi::Inference::OpenAiCompletions.perform!(
      prompt,
      "gpt-3.5-turbo",
      stream: true,
    ) do |partial, cancel|
      data = partial[:choices][0].dig(:delta, :content)
      content << data if data
      cancel.call if content.split(" ").length == 2
    end

    expect(content).to eq("Mountain Tree ")
  end
end
