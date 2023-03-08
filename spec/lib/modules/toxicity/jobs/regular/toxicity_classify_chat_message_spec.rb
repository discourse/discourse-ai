# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../support/toxicity_inference_stubs"

describe Jobs::ToxicityClassifyChatMessage do
  describe "#execute" do
    before do
      SiteSetting.ai_toxicity_enabled = true
      SiteSetting.ai_toxicity_flag_automatically = true
    end

    fab!(:chat_message) { Fabricate(:chat_message) }

    describe "scenarios where we return early without doing anything" do
      it "does nothing when ai_toxicity_enabled is disabled" do
        SiteSetting.ai_toxicity_enabled = false

        subject.execute({ chat_message_id: chat_message.id })

        expect(ReviewableAIChatMessage.where(target: chat_message).count).to be_zero
      end

      it "does nothing if there's no arg called post_id" do
        subject.execute({})

        expect(ReviewableAIChatMessage.where(target: chat_message).count).to be_zero
      end

      it "does nothing if no post match the given id" do
        subject.execute({ chat_message_id: nil })

        expect(ReviewableAIChatMessage.where(target: chat_message).count).to be_zero
      end

      it "does nothing if the post content is blank" do
        chat_message.update_columns(message: "")

        subject.execute({ chat_message_id: chat_message.id })

        expect(ReviewableAIChatMessage.where(target: chat_message).count).to be_zero
      end
    end

    it "flags the message when classified as toxic" do
      ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: true)

      subject.execute({ chat_message_id: chat_message.id })

      expect(ReviewableAIChatMessage.where(target: chat_message).count).to eq(1)
    end
  end
end
