# frozen_string_literal: true

require_relative "support/toxicity_inference_stubs"

describe Plugin::Instance do
  before { SiteSetting.discourse_ai_enabled = true }

  describe "on reviewable_transitioned_to event" do
    fab!(:post)
    fab!(:admin)

    it "adjusts model accuracy" do
      ToxicityInferenceStubs.stub_post_classification(post, toxic: true)
      SiteSetting.ai_toxicity_flag_automatically = true
      classification = DiscourseAi::Toxicity::ToxicityClassification.new
      classificator = DiscourseAi::PostClassificator.new(classification)
      classificator.classify!(post)
      reviewable = ReviewableAiPost.find_by(target: post)

      reviewable.perform admin, :agree_and_keep
      accuracy = ModelAccuracy.find_by(classification_type: classification.type)

      expect(accuracy.flags_agreed).to eq(1)
    end
  end

  describe "current_user_serializer#ai_helper_prompts" do
    fab!(:user)

    before do
      assign_fake_provider_to(:ai_helper_model)
      SiteSetting.ai_helper_enabled = true
      SiteSetting.ai_helper_illustrate_post_model = "disabled"
      Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)

      DiscourseAi::AiHelper::Assistant.clear_prompt_cache!
    end

    let(:serializer) { CurrentUserSerializer.new(user, scope: Guardian.new(user)) }

    it "returns the available prompts" do
      expect(serializer.ai_helper_prompts).to be_present
      expect(serializer.ai_helper_prompts.object.count).to eq(6)
    end
  end
end
