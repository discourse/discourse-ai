# frozen_string_literal: true

module Jobs
  class GenerateEmbeddings < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.ai_embeddings_enabled
      return if (topic_id = args[:topic_id]).blank?

      topic = Topic.find_by_id(topic_id)
      return if topic.private_message? && !SiteSetting.ai_embeddings_enabled_for_private_messages
      post = Topic.find_by_id(topic_id).first_post
      return if post.nil? || post.raw.blank?

      DiscourseAI::Embeddings::Topic.new(post.topic).perform!
    end
  end
end
