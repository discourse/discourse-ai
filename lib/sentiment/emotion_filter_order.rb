# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EmotionFilterOrder
      def self.register!(plugin)
        emotions = %w[
          admiration
          amusement
          anger
          annoyance
          approval
          caring
          confusion
          curiosity
          desire
          disappointment
          disapproval
          disgust
          embarrassment
          excitement
          fear
          gratitude
          grief
          joy
          love
          nervousness
          neutral
          optimism
          pride
          realization
          relief
          remorse
          sadness
          surprise
        ]

        emotions.each do |emotion|
          filter_order_emotion = ->(scope, order_direction) do
            emotion_clause = <<~SQL
              SUM(
                CASE 
                  WHEN (classification_results.classification::jsonb->'#{emotion}')::float > 0.1 
                  THEN 1 
                  ELSE 0 
                END
               )::float / COUNT(posts.id)
            SQL
            scope
              .joins(:posts)
              .joins(<<~SQL)
                INNER JOIN classification_results 
                  ON classification_results.target_id = posts.id 
                  AND classification_results.target_type = 'Post' 
                  AND classification_results.model_used = 'SamLowe/roberta-base-go_emotions'
              SQL
              .where(<<~SQL)
                topics.archetype = 'regular' 
                AND topics.deleted_at IS NULL 
                AND posts.deleted_at IS NULL 
                AND posts.post_type = 1
              SQL
              .select(<<~SQL)
                topics.*, 
                #{emotion_clause} AS emotion_#{emotion} 
              SQL
              .group("1")
              .having("#{emotion_clause} > 0.05")
              .order("#{emotion_clause} #{order_direction}")
          end
          plugin.add_filter_custom_filter("order:emotion_#{emotion}", &filter_order_emotion)
        end
      end
    end
  end
end
