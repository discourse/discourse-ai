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

  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  let(:gemini_mock) { GeminiMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Gemini, user)
  end

  it "Supports Vision API" do
    SiteSetting.ai_gemini_api_key = "ABC"

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are image bot",
        messages: [type: :user, id: "user1", content: "hello", upload_ids: [upload100x100.id]],
      )

    encoded = prompt.encoded_uploads(prompt.messages.last)

    response = gemini_mock.response("World").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy("google:gemini-1.5-pro")
    url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=ABC"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate(prompt, user: user)

    expect(response).to eq("World")

    expected_prompt = {
      "generationConfig" => {
      },
      "safetySettings" => [
        { "category" => "HARM_CATEGORY_HARASSMENT", "threshold" => "BLOCK_NONE" },
        { "category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold" => "BLOCK_NONE" },
        { "category" => "HARM_CATEGORY_HATE_SPEECH", "threshold" => "BLOCK_NONE" },
        { "category" => "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold" => "BLOCK_NONE" },
      ],
      "contents" => [
        {
          "role" => "user",
          "parts" => [
            { "text" => "hello" },
            { "inlineData" => { "mimeType" => "image/jpeg", "data" => encoded[0][:base64] } },
          ],
        },
      ],
      "systemInstruction" => {
        "role" => "system",
        "parts" => [{ "text" => "You are image bot" }],
      },
    }

    expect(JSON.parse(req_body)).to eq(expected_prompt)
  end

  it "Can correctly handle streamed responses even if they are chunked badly" do
    SiteSetting.ai_gemini_api_key = "ABC"

    data = +""
    data << "da|ta: |"
    data << gemini_mock.response("Hello").to_json
    data << "\r\n\r\ndata: "
    data << gemini_mock.response(" |World").to_json
    data << "\r\n\r\ndata: "
    data << gemini_mock.response(" Sam").to_json

    split = data.split("|")

    llm = DiscourseAi::Completions::Llm.proxy("google:gemini-1.5-flash")
    url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:streamGenerateContent?alt=sse&key=ABC"

    output = +""
    gemini_mock.with_chunk_array_support do
      stub_request(:post, url).to_return(status: 200, body: split)
      llm.generate("Hello", user: user) { |partial| output << partial }
    end

    expect(output).to eq("Hello World Sam")
  end
end
