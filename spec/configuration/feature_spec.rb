# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Configuration::Feature do
  fab!(:llm_model)
  fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

  def allow_configuring_setting(&block)
    DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) { block.call }
  end

  describe "#llm_model" do
    context "when persona is not found" do
      it "returns nil when persona_id is invalid" do
        ai_feature =
          described_class.new(
            "topic_summaries",
            "ai_summarization_persona",
            DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
            DiscourseAi::Configuration::Module::SUMMARIZATION,
          )

        SiteSetting.ai_summarization_persona = 999_999
        expect(ai_feature.llm_model).to be_nil
      end
    end

    context "with summarization module" do
      let(:ai_feature) do
        described_class.new(
          "topic_summaries",
          "ai_summarization_persona",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )
      end

      it "returns the configured llm model" do
        SiteSetting.ai_summarization_persona = ai_persona.id
        allow_configuring_setting { SiteSetting.ai_summarization_model = "custom:#{llm_model.id}" }
        expect(ai_feature.llm_model).to eq(llm_model)
      end
    end

    context "with AI helper module" do
      let(:ai_feature) do
        described_class.new(
          "proofread",
          "ai_helper_proofreader_persona",
          DiscourseAi::Configuration::Module::AI_HELPER_ID,
          DiscourseAi::Configuration::Module::AI_HELPER,
        )
      end

      it "returns the persona's default llm when no specific helper model is set" do
        SiteSetting.ai_helper_proofreader_persona = ai_persona.id
        SiteSetting.ai_helper_model = ""

        expect(ai_feature.llm_model).to eq(llm_model)
      end
    end

    context "with translation module" do
      fab!(:translation_model) { Fabricate(:llm_model) }

      let(:ai_feature) do
        described_class.new(
          "locale_detector",
          "ai_translation_locale_detector_persona",
          DiscourseAi::Configuration::Module::TRANSLATION_ID,
          DiscourseAi::Configuration::Module::TRANSLATION,
        )
      end

      it "uses translation model when configured" do
        SiteSetting.ai_translation_locale_detector_persona = ai_persona.id
        ai_persona.update!(default_llm_id: nil)
        allow_configuring_setting do
          SiteSetting.ai_translation_model = "custom:#{translation_model.id}"
        end

        expect(ai_feature.llm_model).to eq(translation_model)
      end
    end
  end

  describe "#enabled?" do
    it "returns true when no enabled_by_setting is specified" do
      ai_feature =
        described_class.new(
          "topic_summaries",
          "ai_summarization_persona",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )

      expect(ai_feature.enabled?).to be true
    end

    it "respects the enabled_by_setting when specified" do
      ai_feature =
        described_class.new(
          "gists",
          "ai_summary_gists_persona",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
          enabled_by_setting: "ai_summary_gists_enabled",
        )

      SiteSetting.ai_summary_gists_enabled = false
      expect(ai_feature.enabled?).to be false

      SiteSetting.ai_summary_gists_enabled = true
      expect(ai_feature.enabled?).to be true
    end
  end

  describe "#persona_id" do
    it "returns the persona id from site settings" do
      ai_feature =
        described_class.new(
          "topic_summaries",
          "ai_summarization_persona",
          DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
          DiscourseAi::Configuration::Module::SUMMARIZATION,
        )

      SiteSetting.ai_summarization_persona = ai_persona.id
      expect(ai_feature.persona_id).to eq(ai_persona.id)
    end
  end

  describe ".find_features_using" do
    it "returns all features using a specific persona" do
      SiteSetting.ai_summarization_persona = ai_persona.id
      SiteSetting.ai_helper_proofreader_persona = ai_persona.id
      SiteSetting.ai_translation_locale_detector_persona = 999

      features = described_class.find_features_using(persona_id: ai_persona.id)

      expect(features.map(&:name)).to include("topic_summaries", "proofread")
      expect(features.map(&:name)).not_to include("locale_detector")
    end
  end
end
