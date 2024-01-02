# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::Gemini do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::OpenAiTokenizer) }

  let(:model_name) { "gemini-pro" }
  let(:generic_prompt) { { insts: "You are a helpful bot.", input: "write 3 words" } }
  let(:dialect) { DiscourseAi::Completions::Dialects::Gemini.new(generic_prompt, model_name) }
  let(:prompt) { dialect.translate }

  let(:tool_id) { "get_weather" }

  let(:tool_payload) do
    {
      name: "get_weather",
      description: "Get the weather in a city",
      parameters: [
        { name: "location", type: "string", description: "the city name" },
        {
          name: "unit",
          type: "string",
          description: "the unit of measurement celcius c or fahrenheit f",
          enum: %w[c f],
        },
      ],
      required: %w[location unit],
    }
  end

  let(:request_body) do
    model
      .default_options
      .merge(contents: prompt)
      .tap { |b| b[:tools] = [{ function_declarations: [tool_payload] }] if generic_prompt[:tools] }
      .to_json
  end
  let(:stream_request_body) do
    model
      .default_options
      .merge(contents: prompt)
      .tap { |b| b[:tools] = [{ function_declarations: [tool_payload] }] if generic_prompt[:tools] }
      .to_json
  end

  let(:tool_deltas) do
    [
      { "functionCall" => { name: "get_weather", args: {} } },
      { "functionCall" => { name: "get_weather", args: { location: "" } } },
      { "functionCall" => { name: "get_weather", args: { location: "Sydney", unit: "c" } } },
    ]
  end

  let(:tool_call) do
    { "functionCall" => { name: "get_weather", args: { location: "Sydney", unit: "c" } } }
  end

  def response(content, tool_call: false)
    {
      candidates: [
        {
          content: {
            parts: [(tool_call ? content : { text: content })],
            role: "model",
          },
          finishReason: "STOP",
          index: 0,
          safetyRatings: [
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
          ],
        },
      ],
      promptFeedback: {
        safetyRatings: [
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
          { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
        ],
      },
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/#{model_name}:generateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: request_body)
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta, finish_reason: nil, tool_call: false)
    {
      candidates: [
        {
          content: {
            parts: [(tool_call ? delta : { text: delta })],
            role: "model",
          },
          finishReason: finish_reason,
          index: 0,
          safetyRatings: [
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
          ],
        },
      ],
    }.to_json
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "STOP", tool_call: tool_call)
        else
          stream_line(deltas[index], tool_call: tool_call)
        end
      end

    chunks = chunks.join("\n,\n").prepend("[").concat("\n]").split("")

    WebMock
      .stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/#{model_name}:streamGenerateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: stream_request_body)
      .to_return(status: 200, body: chunks)
  end

  it_behaves_like "an endpoint that can communicate with a completion service"
end
