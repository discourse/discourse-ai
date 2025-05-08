# frozen_string_literal: true

module Jobs
  class GenerateConceptsFromPopularTopics < ::Jobs::Scheduled
    every 1.day
    
    # This job runs daily and generates new concepts from popular topics
    # It selects topics based on engagement metrics and generates concepts from their content
    def execute(args = {})
      # Find candidate topics that are popular and don't have concepts yet
      candidates = DiscourseAi::InferredConcepts::Manager.find_candidate_topics(
        limit: SiteSetting.inferred_concepts_daily_topics_limit || 20,
        min_posts: SiteSetting.inferred_concepts_min_posts || 5,
        min_likes: SiteSetting.inferred_concepts_min_likes || 10,
        min_views: SiteSetting.inferred_concepts_min_views || 100,
        created_after: SiteSetting.inferred_concepts_lookback_days.days.ago
      )
      
      return if candidates.blank?
      
      # Process the candidate topics in batches using the regular job
      Jobs.enqueue(
        :generate_inferred_concepts,
        topic_ids: candidates.map(&:id),
        batch_size: 10
      )
      
      # Schedule a follow-up job to apply the concepts to topics
      # This runs after a delay to ensure concepts have been generated
      Jobs.enqueue_in(
        1.hour,
        :apply_inferred_concepts,
        topic_ids: candidates.map(&:id),
        batch_size: 10
      )
    end
  end
end