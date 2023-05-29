# frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::Summarization::Strategies::OpenAi do
  it "asks a OpenAI's model to summarize the content" do
    summarization_text = "This is a text"
    expected_response = "This is a summary"

    OpenAiCompletionsInferenceStubs.stub_response(
      subject.prompt(summarization_text),
      expected_response,
    )

    expect(subject.summarize(summarization_text)).to eq(expected_response)
  end
end
