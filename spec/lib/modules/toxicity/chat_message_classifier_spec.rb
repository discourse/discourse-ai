# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/toxicity_inference_stubs"

describe DiscourseAI::Toxicity::ChatMessageClassifier do
  before { SiteSetting.ai_toxicity_flag_automatically = true }

  fab!(:chat_message) { Fabricate(:chat_message) }

  describe "#classify!" do
    it "creates a reviewable when the post is classified as toxic" do
      ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: true)

      subject.classify!(chat_message)

      expect(ReviewableChatMessage.where(target: chat_message).count).to eq(1)
    end

    it "doesn't create a reviewable if the post is not classified as toxic" do
      ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: false)

      subject.classify!(chat_message)

      expect(ReviewableChatMessage.where(target: chat_message).count).to be_zero
    end

    it "doesn't create a reviewable if flagging is disabled" do
      SiteSetting.ai_toxicity_flag_automatically = false
      ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: true)

      subject.classify!(chat_message)

      expect(ReviewableChatMessage.where(target: chat_message).count).to be_zero
    end

    it "stores the classification in a custom field" do
      ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: false)

      subject.classify!(chat_message)
      store_row = PluginStore.get("toxicity", "chat_message_#{chat_message.id}").deep_symbolize_keys

      expect(store_row[:classification]).to eq(ToxicityInferenceStubs.civilized_response)
      expect(store_row[:model]).to eq(SiteSetting.ai_toxicity_inference_service_api_model)
      expect(store_row[:date]).to be_present
    end
  end
end
