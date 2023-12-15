# frozen_string_literal: true

require_relative "endpoint_examples"

RSpec.describe DiscourseAi::Completions::Endpoints::Gemini do
  subject(:model) { described_class.new(model_name, DiscourseAi::Tokenizer::OpenAiTokenizer) }

  let(:model_name) { "gemini-pro" }
  let(:prompt) do
    [
      { role: "system", content: "You are a helpful bot." },
      { role: "user", content: "Write 3 words" },
    ]
  end

  let(:request_body) { model.default_options.merge(contents: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(contents: prompt).to_json }

  def response(content)
    {
      candidates: [
        {
          content: {
            parts: [{ text: content }],
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

  def stub_response(prompt, response_text)
    WebMock
      .stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/#{model_name}:generateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: { contents: prompt })
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    {
      candidates: [
        {
          content: {
            parts: [{ text: delta }],
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

  def stub_streamed_response(prompt, deltas)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "STOP")
        else
          stream_line(deltas[index])
        end
      end

    chunks = chunks.join("\n,\n").prepend("[\n").concat("\n]")

    WebMock
      .stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/#{model_name}:streamGenerateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: model.default_options.merge(contents: prompt).to_json)
      .to_return(status: 200, body: chunks)
  end

  it_behaves_like "an endpoint that can communicate with a completion service"
end
