# frozen_string_literal: true

module Jobs
  class EmbeddingsBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.ai_embeddings_enabled

      limit = SiteSetting.ai_embeddings_backfill_batch_size

      if limit > 50_000
        limit = 50_000
        Rails.logger.warn(
          "Limiting backfill batch size to 50,000 to avoid OOM errors, reduce ai_embeddings_backfill_batch_size to avoid this warning",
        )
      end

      rebaked = 0

      strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
      table_name = vector_rep.topic_table_name

      topics =
        Topic
          .joins("LEFT JOIN #{table_name} ON #{table_name}.topic_id = topics.id")
          .where(archetype: Archetype.default)
          .where(deleted_at: nil)
          .order("topics.bumped_at DESC")
          .limit(limit - rebaked)

      rebaked += populate_topic_embeddings(vector_rep, topics)

      return if rebaked >= limit

      # Then, we'll try to backfill embeddings for topics that have outdated
      # embeddings, be it model or strategy version
      relation = topics.where(<<~SQL)
          #{table_name}.model_version < #{vector_rep.version}
          OR
          #{table_name}.strategy_version < #{strategy.version}
        SQL

      rebaked += populate_topic_embeddings(vector_rep, relation)

      return if rebaked >= limit

      # Finally, we'll try to backfill embeddings for topics that have outdated
      # embeddings due to edits or new replies. Here we only do 10% of the limit
      relation =
        topics
          .where("#{table_name}.updated_at < ?", 6.hours.ago)
          .where("#{table_name}.updated_at < topics.updated_at")
          .limit((limit - rebaked) / 10)

      populate_topic_embeddings(vector_rep, relation, force: true)

      return if rebaked >= limit

      return unless SiteSetting.ai_embeddings_per_post_enabled

      # Now for posts
      table_name = vector_rep.post_table_name

      posts =
        Post
          .joins("LEFT JOIN #{table_name} ON #{table_name}.post_id = posts.id")
          .where(deleted_at: nil)
          .limit(limit - rebaked)

      # First, we'll try to backfill embeddings for posts that have none
      posts
        .where("#{table_name}.post_id IS NULL")
        .find_each do |t|
          vector_rep.generate_representation_from(t)
          rebaked += 1
        end

      return if rebaked >= limit

      # Then, we'll try to backfill embeddings for posts that have outdated
      # embeddings, be it model or strategy version
      posts
        .where(<<~SQL)
          #{table_name}.model_version < #{vector_rep.version}
          OR
          #{table_name}.strategy_version < #{strategy.version}
        SQL
        .find_each do |t|
          vector_rep.generate_representation_from(t)
          rebaked += 1
        end

      return if rebaked >= limit

      # Finally, we'll try to backfill embeddings for posts that have outdated
      # embeddings due to edits. Here we only do 10% of the limit
      posts
        .where("#{table_name}.updated_at < ?", 7.days.ago)
        .order("random()")
        .limit((limit - rebaked) / 10)
        .pluck(:id)
        .each do |id|
          vector_rep.generate_representation_from(Post.find_by(id: id))
          rebaked += 1
        end

      rebaked
    end

    private

    def populate_topic_embeddings(vector_rep, topics, force: false)
      done = 0

      topics = topics.where("#{vector_rep.topic_table_name}.topic_id IS NULL") if !force

      ids = topics.pluck("topics.id")

      ids.each do |id|
        topic = Topic.find_by(id: id)
        if topic
          vector_rep.generate_representation_from(topic)
          done += 1
        end
      end
      done
    end
  end
end
