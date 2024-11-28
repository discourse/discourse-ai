# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class SemanticCategorizer
      def initialize(input, user)
        @user = user
        @text = input[:text]
      end

      def categories
        return [] if @text.blank?
        return [] unless SiteSetting.ai_embeddings_enabled

        candidates = nearest_neighbors(limit: 100)
        candidate_ids = candidates.map(&:first)

        ::Topic
          .joins(:category)
          .where(id: candidate_ids)
          .where("categories.id IN (?)", Category.topic_create_allowed(@user.guardian).pluck(:id))
          .order("array_position(ARRAY#{candidate_ids}, topics.id)")
          .pluck(
            "categories.id",
            "categories.name",
            "categories.slug",
            "categories.color",
            "categories.topic_count",
          )
          .map
          .with_index do |(id, name, slug, color, topic_count), index|
            {
              id: id,
              name: name,
              slug: slug,
              color: color,
              topicCount: topic_count,
              score: candidates[index].last,
            }
          end
          .map do |c|
            c[:score] = 1 / (c[:score] + 1) # inverse of the distance
            c
          end
          .group_by { |c| c[:name] }
          .map { |name, scores| scores.first.merge(score: scores.sum { |s| s[:score] }) }
          .sort_by { |c| -c[:score] }
          .take(5)
      end

      def tags
        return [] if @text.blank?
        return [] unless SiteSetting.ai_embeddings_enabled

        candidates = nearest_neighbors(limit: 100)
        candidate_ids = candidates.map(&:first)

        count_column = Tag.topic_count_column(@user.guardian) # Determine the count column

        ::Topic
          .joins(:topic_tags, :tags)
          .where(id: candidate_ids)
          .where("tags.id IN (?)", DiscourseTagging.visible_tags(@user.guardian).pluck(:id))
          .group("topics.id")
          .order("array_position(ARRAY#{candidate_ids}, topics.id)")
          .pluck("array_agg(tags.name)")
          .map(&:uniq)
          .map
          .with_index { |tag_list, index| { tags: tag_list, score: candidates[index].last } }
          .flat_map { |c| c[:tags].map { |t| { name: t, score: c[:score] } } }
          .map do |c|
            c[:score] = 1 / (c[:score] + 1) # inverse of the distance
            c
          end
          .group_by { |c| c[:name] }
          .map { |name, scores| { name: name, score: scores.sum { |s| s[:score] } } }
          .sort_by { |c| -c[:score] }
          .take(5)
          .then do |tags|
            models = Tag.where(name: tags.map { _1[:name] }).index_by(&:name)
            tags.map do |tag|
              tag[:id] = models.dig(tag[:name])&.id
              tag[:count] = models.dig(tag[:name])&.public_send(count_column) || 0
              tag
            end
          end
      end

      private

      def nearest_neighbors(limit: 100)
        strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
        vector_rep =
          DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

        raw_vector = vector_rep.vector_from(@text)

        vector_rep.asymmetric_topics_similarity_search(
          raw_vector,
          limit: limit,
          offset: 0,
          return_distance: true,
        )
      end
    end
  end
end
