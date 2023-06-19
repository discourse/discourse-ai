# frozen_string_literal: true
require "rails_helper"

require_relative "../../support/openai_completions_inference_stubs"

describe DiscourseAi::Inference::OpenAiCompletions do
  before { SiteSetting.ai_openai_api_key = "abc-123" }

  it "supports function calling" do
    prompt = [role: "system", content: "you are weatherbot"]
    prompt << { role: "user", content: "what is the weather in sydney?" }

    functions = []

    function =
      DiscourseAi::Inference::OpenAiCompletions::Function.new(
        name: "get_weather",
        description: "Get the weather in a city",
      )

    function.add_parameter(
      name: "location",
      type: "string",
      description: "the city name",
      required: true,
    )

    function.add_parameter(
      name: "unit",
      type: "string",
      description: "the unit of measurement celcius c or fahrenheit f",
      enum: %w[c f],
      required: true,
    )

    functions << function

    function_calls = []
    current_function_call = nil

    deltas = [
      { role: "assistant" },
      { function_call: { name: "get_weather", arguments: "" } },
      { function_call: { arguments: "{ \"location\": " } },
      { function_call: { arguments: "\"sydney\", \"unit\": \"c\" }" } },
    ]

    OpenAiCompletionsInferenceStubs.stub_streamed_response(
      prompt,
      deltas,
      model: "gpt-3.5-turbo-0613",
      req_opts: {
        functions: functions,
        stream: true,
      },
    )

    DiscourseAi::Inference::OpenAiCompletions.perform!(
      prompt,
      "gpt-3.5-turbo-0613",
      functions: functions,
    ) do |json, cancel|
      fn = json.dig(:choices, 0, :delta, :function_call)
      if fn && fn[:name]
        current_function_call = { name: fn[:name], arguments: +fn[:arguments].to_s.dup }
        function_calls << current_function_call
      elsif fn && fn[:arguments] && current_function_call
        current_function_call[:arguments] << fn[:arguments]
      end
    end

    expect(function_calls.length).to eq(1)
    expect(function_calls[0][:name]).to eq("get_weather")
    expect(JSON.parse(function_calls[0][:arguments])).to eq(
      { "location" => "sydney", "unit" => "c" },
    )

    prompt << { role: "function", name: "get_weather", content: 22.to_json }

    OpenAiCompletionsInferenceStubs.stub_response(
      prompt,
      "The current temperature in Sydney is 22 degrees Celsius.",
      model: "gpt-3.5-turbo-0613",
      req_opts: {
        functions: functions,
      },
    )

    result =
      DiscourseAi::Inference::OpenAiCompletions.perform!(
        prompt,
        "gpt-3.5-turbo-0613",
        functions: functions,
      )

    expect(result.dig(:choices, 0, :message, :content)).to eq(
      "The current temperature in Sydney is 22 degrees Celsius.",
    )
  end

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
    expect(log.request_tokens).to eq(4)
    expect(log.response_tokens).to eq(3)
    expect(log.raw_request_payload).to eq(request_body)
    expect(log.raw_response_payload).to be_present
  end
end
