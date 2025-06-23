# frozen_string_literal: true

describe DiscourseAi::Translation::BaseTranslator do
  let!(:persona) do
    AiPersona.find(
      DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::PostRawTranslator],
    )
  end

  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end

    SiteSetting.ai_translation_enabled = true
  end

  describe ".translate" do
    let(:text) { "cats are great" }
    let(:target_locale) { "de" }
    let(:llm_response) { "hur dur hur dur!" }
    fab!(:post)

    it "creates the correct prompt" do
      post_translator =
        DiscourseAi::Translation::PostRawTranslator.new(text:, target_locale:, post:)
      allow(DiscourseAi::Completions::Prompt).to receive(:new).with(
        persona.system_prompt,
        messages: array_including({ type: :user, content: a_string_including(text) }),
        post_id: post.id,
        topic_id: post.topic_id,
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
        post_translator.translate
      end
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
