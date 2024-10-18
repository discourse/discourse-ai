# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def inject_into(plugin)
        plugin.add_to_serializer(:current_user, :can_summarize) do
          return false if !SiteSetting.ai_summarization_enabled
          scope.user.in_any_groups?(SiteSetting.ai_custom_summarization_allowed_groups_map)
        end

        plugin.add_to_serializer(:topic_view, :summarizable) do
          scope.can_see_summary?(object.topic, AiSummary.summary_types[:complete])
        end

        plugin.add_to_serializer(:web_hook_topic_view, :summarizable) do
          scope.can_see_summary?(object.topic, AiSummary.summary_types[:complete])
        end

        plugin.register_modifier(:topic_query_create_list_topics) do |topics, options|
          if options[:filter] == :hot && SiteSetting.ai_summarization_enabled &&
               SiteSetting.ai_summarize_max_hot_topics_gists_per_batch > 0
            topics.includes(:ai_summaries).where(
              "ai_summaries.id IS NULL OR ai_summaries.summary_type = ?",
              AiSummary.summary_types[:gist],
            )
          else
            topics
          end
        end

        plugin.add_to_serializer(
          :topic_list_item,
          :ai_topic_gist,
          include_condition: -> do
            SiteSetting.ai_summarization_enabled &&
              SiteSetting.ai_summarize_max_hot_topics_gists_per_batch > 0 &&
              options[:filter] == :hot
          end,
        ) do
          summaries = object.ai_summaries.to_a

          # Summaries should always have one or zero elements here.
          # This is an extra safeguard to avoid including regular summaries.
          summaries.find { |s| s.summary_type == "gist" }&.summarized_text
        end

        # To make sure hot topic gists are inmediately up to date, we rely on this event
        # instead of using a scheduled job.
        plugin.on(:topic_hot_scores_updated) { Jobs.enqueue(:hot_topics_gist_batch) }
      end
    end
  end
end
