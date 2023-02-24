# frozen_string_literal: true

require "rails_helper"
require_relative "../support/toxicity_inference_stubs"

describe DiscourseAI::ChatMessageClassification do
  fab!(:chat_message) { Fabricate(:chat_message) }

  let(:model) { DiscourseAI::Toxicity::ToxicityClassification.new }
  let(:classification) { described_class.new(model) }

  describe "#classify!" do
    before { ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: true) }

    it "stores the model classification data in a custom field" do
      classification.classify!(chat_message)
      store_row = PluginStore.get("toxicity", "chat_message_#{chat_message.id}")

      classified_data =
        store_row[SiteSetting.ai_toxicity_inference_service_api_model].symbolize_keys

      expect(classified_data).to eq(ToxicityInferenceStubs.toxic_response)
      expect(store_row[:date]).to be_present
    end

    it "flags the message when the model decides we should" do
      SiteSetting.ai_toxicity_flag_automatically = true

      classification.classify!(chat_message)

      expect(ReviewableChatMessage.where(target: chat_message).count).to eq(1)
    end

    it "doesn't flags the message if the model decides we shouldn't" do
      SiteSetting.ai_toxicity_flag_automatically = false

      classification.classify!(chat_message)

      expect(ReviewableChatMessage.where(target: chat_message).count).to be_zero
    end
  end
end
