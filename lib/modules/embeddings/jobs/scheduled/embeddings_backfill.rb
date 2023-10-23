# frozen_string_literal: true

module Jobs
  class EmbeddingsBackfill < ::Jobs::Scheduled
    every 15.minutes
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.ai_embeddings_enabled

      limit = SiteSetting.ai_embeddings_backfill_batch_size
      rebaked = 0

      strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
      table_name = vector_rep.table_name

      topics =
        Topic
          .joins("LEFT JOIN #{table_name} ON #{table_name}.topic_id = topics.id")
          .where(archetype: Archetype.default)
          .where(deleted_at: nil)
          .order("#{table_name}.updated_at ASC NULLS FIRST, topics.id DESC")
          .limit(limit - rebaked)

      # First, we'll try to backfill embeddings for topics that have none
      topics
        .where("#{table_name}.topic_id IS NULL")
        .find_each do |t|
          vector_rep.generate_topic_representation_from(t)
          rebaked += 1
        end

      return if rebaked >= limit

      consider_indexing(vector_rep)

      # Then, we'll try to backfill embeddings for topics that have outdated
      # embeddings, be it model or strategy version
      topics
        .where(<<~SQL)
          #{table_name}.model_version < #{vector_rep.version}
          OR
          #{table_name}.strategy_version < #{strategy.version}
        SQL
        .find_each do |t|
          vector_rep.generate_topic_representation_from(t)
          rebaked += 1
        end

      return if rebaked >= limit

      # Finally, we'll try to backfill embeddings for topics that have outdated
      # embeddings due to edits or new replies. Here we only do 10% of the limit
      topics
        .reorder("random()")
        .limit((limit - rebaked) / 10)
        .find_each do |t|
          vector_rep.generate_topic_representation_from(t)
          rebaked += 1
        end

      rebaked
    end

    private

    def consider_indexing(vector_rep)
      limiter = RateLimiter.new(nil, "ai_embeddings_backfill_indexing", 1, 1.week)

      if limiter.can_perform?
        vector_rep.create_index(memory: "100MB")
        limiter.performed!
      end
    end
  end
end
