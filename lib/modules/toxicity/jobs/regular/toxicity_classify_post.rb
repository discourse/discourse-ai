# frozen_string_literal: true

module ::Jobs
  class ToxicityClassifyPost < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.ai_toxicity_enabled

      post_id = args[:post_id]
      return if post_id.blank?

      post = Post.find_by(id: post_id, post_type: Post.types[:regular])
      return if post&.raw.blank?

      DiscourseAI::PostClassificator.new(
        DiscourseAI::Toxicity::ToxicityClassification.new,
      ).classify!(post)
    end
  end
end
