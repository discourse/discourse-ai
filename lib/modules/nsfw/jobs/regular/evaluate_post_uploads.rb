# frozen_string_literal: true

module Jobs
  class EvaluatePostUploads < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.ai_nsfw_detection_enabled
      return if (post_id = args[:post_id]).blank?

      post = Post.includes(:uploads).find_by_id(post_id)
      return if post.nil? || post.uploads.empty?

      nsfw_evaluation = DiscourseAI::NSFW::Evaluation.new

      image_uploads = post.uploads.select { |upload| FileHelper.is_supported_image?(upload.url) }

      results = image_uploads.map { |upload| nsfw_evaluation.perform(upload) }

      DiscourseAI::FlagManager.new(post).flag! if results.any? { |r| r[:verdict] }
    end
  end
end
