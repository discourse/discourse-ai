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

      strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

      vector_rep.generate_topic_representation_from(topic)
    end
  end
end
