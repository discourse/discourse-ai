# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Translation::BaseTranslator do
  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end
  end

  describe ".translate" do
    let(:text) { "cats are great" }
    let(:target_locale) { "de" }
    let(:llm_response) { "hur dur hur dur!" }

    it "creates the correct prompt" do
      post_translator =
        DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:, topic_id: 1)
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        DiscourseAi::Translation::PostRawTranslator::PROMPT_TEMPLATE,
        messages: [{ type: :user, content: post_translator.formatted_content, id: "user" }],
        topic_id: 1,
        post_id: nil,
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        post_translator.translate
      end
    end

    it "sends the translation prompt to the selected ai helper model" do
      mock_prompt = instance_double(DiscourseAi::Completions::Prompt)
      mock_llm = instance_double(DiscourseAi::Completions::Llm)
      post_translator = DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:)

      structured_output =
        DiscourseAi::Completions::StructuredOutput.new({ translation: { type: "string" } })
      structured_output << { translation: llm_response }.to_json

      allow(DiscourseAi::Completions::Prompt).to receive(:new).and_return(mock_prompt)
      allow(DiscourseAi::Completions::Llm).to receive(:proxy).with(
        SiteSetting.ai_translation_model,
      ).and_return(mock_llm)
      allow(mock_llm).to receive(:generate).with(
        mock_prompt,
        user: Discourse.system_user,
        feature_name: "translation",
        response_format: post_translator.response_format,
      ).and_return(structured_output)

      post_translator.translate
    end

    it "returns the translation from the llm's response" do
      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        expect(
          DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:).translate,
        ).to eq "hur dur hur dur!"
      end
    end
  end
end
