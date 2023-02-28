# frozen_string_literal: true

module Jobs
  class EvaluatePostUploads < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.ai_nsfw_detection_enabled
      return if (post_id = args[:post_id]).blank?

      post = Post.includes(:uploads).find_by_id(post_id)
      return if post.nil? || post.uploads.empty?

      return if post.uploads.none? { |u| FileHelper.is_supported_image?(u.url) }

      DiscourseAI::PostClassificator.new(DiscourseAI::NSFW::NSFWClassification.new).classify!(post)
    end
  end
end
