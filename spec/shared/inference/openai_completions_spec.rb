# frozen_string_literal: true
require "rails_helper"

require_relative "../../support/openai_completions_inference_stubs"

describe DiscourseAi::Inference::OpenAiCompletions do
  before { SiteSetting.ai_openai_api_key = "abc-123" }

  context "when configured using Azure" do
    it "Supports custom Azure endpoints for completions" do
      gpt_url_base =
        "https://company.openai.azure.com/openai/deployments/deployment/chat/completions?api-version=2023-03-15-preview"
      key = "12345"
      SiteSetting.ai_openai_api_key = key

      [
        { setting_name: "ai_openai_gpt35_url", model: "gpt-35-turbo" },
        { setting_name: "ai_openai_gpt35_16k_url", model: "gpt-35-16k-turbo" },
        { setting_name: "ai_openai_gpt4_url", model: "gpt-4" },
        { setting_name: "ai_openai_gpt4_32k_url", model: "gpt-4-32k" },
      ].each do |config|
        gpt_url = "#{gpt_url_base}/#{config[:model]}"
        setting_name = config[:setting_name]
        model = config[:model]

        SiteSetting.public_send("#{setting_name}=".to_sym, gpt_url)

        expected = {
          id: "chatcmpl-7TfPzOyBGW5K6dyWp3NPU0mYLGZRQ",
          object: "chat.completion",
          created: 1_687_305_079,
          model: model,
          choices: [
            {
              index: 0,
              finish_reason: "stop",
              message: {
                role: "assistant",
                content: "Hi there! How can I assist you today?",
              },
            },
          ],
          usage: {
            completion_tokens: 10,
            prompt_tokens: 9,
            total_tokens: 19,
          },
        }

        stub_request(:post, gpt_url).with(
          body: "{\"model\":\"#{model}\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}",
          headers: {
            "Api-Key" => "12345",
            "Content-Type" => "application/json",
            "Host" => "company.openai.azure.com",
          },
        ).to_return(status: 200, body: expected.to_json, headers: {})

        result =
          DiscourseAi::Inference::OpenAiCompletions.perform!(
            [role: "user", content: "hello"],
            model,
          )

        expect(result).to eq(expected)
      end
    end
  end

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
