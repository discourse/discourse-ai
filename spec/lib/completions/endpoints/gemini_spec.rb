# frozen_string_literal: true

require_relative "endpoint_compliance"

class GeminiMock < EndpointMock
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
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: request_body(prompt, tool_call))
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

    chunks = chunks.join("\n,\n").prepend("[\n").concat("\n]").split("")

    WebMock
      .stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: request_body(prompt, tool_call))
      .to_return(status: 200, body: chunks)
  end

  def tool_payload
    {
      name: "get_weather",
      description: "Get the weather in a city",
      parameters: {
        type: "object",
        required: %w[location unit],
        properties: {
          "location" => {
            type: "string",
            description: "the city name",
          },
          "unit" => {
            type: "string",
            description: "the unit of measurement celcius c or fahrenheit f",
            enum: %w[c f],
          },
        },
      },
    }
  end

  def request_body(prompt, tool_call)
    model
      .default_options
      .merge(contents: prompt)
      .tap { |b| b[:tools] = [{ function_declarations: [tool_payload] }] if tool_call }
      .to_json
  end

  def tool_deltas
    [
      { "functionCall" => { name: "get_weather", args: {} } },
      { "functionCall" => { name: "get_weather", args: { location: "" } } },
      { "functionCall" => { name: "get_weather", args: { location: "Sydney", unit: "c" } } },
    ]
  end

  def tool_response
    { "functionCall" => { name: "get_weather", args: { location: "Sydney", unit: "c" } } }
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Gemini do
  subject(:endpoint) { described_class.new("gemini-pro", DiscourseAi::Tokenizer::OpenAiTokenizer) }

  fab!(:user)

  let(:gemini_mock) { GeminiMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Gemini, user)
  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.regular_mode_simple_prompt(gemini_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(gemini_mock)
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(gemini_mock)
        end
      end

      context "with tools" do
        it "returns a function invocation" do
          compliance.streaming_mode_tools(gemini_mock)
        end
      end
    end
  end
end
