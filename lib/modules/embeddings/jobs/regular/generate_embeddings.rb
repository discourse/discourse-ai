# frozen_string_literal: true

module Jobs
  class GenerateEmbeddings < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.ai_embeddings_enabled
      return if (topic_id = args[:topic_id]).blank?

      topic = Topic.find_by_id(topic_id)
      return if topic.nil? || topic.private_message? && !SiteSetting.ai_embeddings_generate_for_pms
      post = topic.first_post
      return if post.nil? || post.raw.blank?

      DiscourseAi::Embeddings::Topic.new.generate_and_store_embeddings_for(topic)
    end
  end
end
