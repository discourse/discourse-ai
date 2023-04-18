# frozen_string_literal: true

require "rails_helper"
require_relative "../support/toxicity_inference_stubs"

describe DiscourseAi::ChatMessageClassificator do
  fab!(:chat_message) { Fabricate(:chat_message) }

  let(:model) { DiscourseAi::Toxicity::ToxicityClassification.new }
  let(:classification) { described_class.new(model) }

  describe "#classify!" do
    before { ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: true) }

    it "stores the model classification data" do
      classification.classify!(chat_message)

      result =
        ClassificationResult.find_by(target_id: chat_message.id, classification_type: model.type)

      classification = result.classification.symbolize_keys

      expect(classification).to eq(ToxicityInferenceStubs.toxic_response)
    end

    it "flags the message when the model decides we should" do
      SiteSetting.ai_toxicity_flag_automatically = true

      classification.classify!(chat_message)

      expect(ReviewableAiChatMessage.where(target: chat_message).count).to eq(1)
    end

    it "doesn't flags the message if the model decides we shouldn't" do
      SiteSetting.ai_toxicity_flag_automatically = false

      classification.classify!(chat_message)

      expect(ReviewableAiChatMessage.where(target: chat_message).count).to be_zero
    end

    it "includes the model accuracy in the payload" do
      SiteSetting.ai_toxicity_flag_automatically = true
      classification.classify!(chat_message)

      reviewable = ReviewableAiChatMessage.find_by(target: chat_message)

      expect(
        reviewable.payload.dig("accuracies", SiteSetting.ai_toxicity_inference_service_api_model),
      ).to be_zero
    end
  end
end
