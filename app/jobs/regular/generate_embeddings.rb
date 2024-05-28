# frozen_string_literal: true

module Jobs
  class GenerateEmbeddings < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return unless SiteSetting.ai_embeddings_enabled
      return if args[:target_type].blank? || args[:target_id].blank?
      target = args[:target_type].constantize.find_by_id(args[:target_id])
      return if target.nil? || target.deleted_at.present?

      topic = target.is_a?(Topic) ? target : target.topic
      post = target.is_a?(Post) ? target : target.first_post
      return if topic.blank? || post.blank?
      return if topic.private_message? && !SiteSetting.ai_embeddings_generate_for_pms
      return if post.raw.blank?

      strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

      vector_rep.generate_representation_from(target)
    end
  end
end
