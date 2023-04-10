# frozen_string_literal: true

require_relative "../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiHelper::LlmPrompt do
  let(:prompt) { CompletionPrompt.find_by(name: mode) }

  describe "#generate_and_send_prompt" do
    context "when using the translate mode" do
      let(:mode) { OpenAiCompletionsInferenceStubs::TRANSLATE }

      before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

      it "Sends the prompt to chatGPT and returns the response" do
        response =
          subject.generate_and_send_prompt(prompt, OpenAiCompletionsInferenceStubs.spanish_text)

        expect(response[:suggestions]).to contain_exactly(
          OpenAiCompletionsInferenceStubs.translated_response.strip,
        )
      end
    end

    context "when using the proofread mode" do
      let(:mode) { OpenAiCompletionsInferenceStubs::PROOFREAD }

      before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

      it "Sends the prompt to chatGPT and returns the response" do
        response =
          subject.generate_and_send_prompt(
            prompt,
            OpenAiCompletionsInferenceStubs.translated_response,
          )

        expect(response[:suggestions]).to contain_exactly(
          OpenAiCompletionsInferenceStubs.proofread_response.strip,
        )
      end
    end

    context "when generating titles" do
      let(:mode) { OpenAiCompletionsInferenceStubs::GENERATE_TITLES }

      before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

      it "returns an array with each title" do
        expected =
          OpenAiCompletionsInferenceStubs
            .generated_titles
            .gsub("\"", "")
            .gsub(/\d./, "")
            .split("\n")
            .map(&:strip)

        response =
          subject.generate_and_send_prompt(
            prompt,
            OpenAiCompletionsInferenceStubs.translated_response,
          )

        expect(response[:suggestions]).to contain_exactly(*expected)
      end
    end
  end
end
