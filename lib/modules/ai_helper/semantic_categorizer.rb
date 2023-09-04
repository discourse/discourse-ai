# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class SemanticCategorizer
      def initialize(text, user)
        @user = user
        @text = text
      end

      def categories
        return [] if @text.blank?
        return [] unless SiteSetting.ai_embeddings_enabled

        candidates =
          ::DiscourseAi::Embeddings::SemanticSearch.new(nil).asymmetric_semantic_search(
            @text,
            100,
            0,
            return_distance: true,
          )
        candidate_ids = candidates.map(&:first)

        ::Topic
          .joins(:category)
          .where(id: candidate_ids)
          .where("categories.id IN (?)", Category.topic_create_allowed(@user.guardian).pluck(:id))
          .order("array_position(ARRAY#{candidate_ids}, topics.id)")
          .pluck("categories.slug")
          .map
          .with_index { |category, index| { name: category, score: candidates[index].last } }
          .map do |c|
            c[:score] = 1 / (c[:score] + 1) # inverse of the distance
            c
          end
          .group_by { |c| c[:name] }
          .map { |name, scores| { name: name, score: scores.sum { |s| s[:score] } } }
          .sort_by { |c| -c[:score] }
          .take(5)
      end

      def tags
        return [] if @text.blank?
        return [] unless SiteSetting.ai_embeddings_enabled

        candidates =
          ::DiscourseAi::Embeddings::SemanticSearch.new(nil).asymmetric_semantic_search(
            @text,
            100,
            0,
            return_distance: true,
          )
        candidate_ids = candidates.map(&:first)

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
      end
    end
  end
end
