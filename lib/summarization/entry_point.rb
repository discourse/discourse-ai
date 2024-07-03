# frozen_string_literal: true

module DiscourseAi
  module Summarization
    def self.default_strategy
      if SiteSetting.ai_summarization_model.present? && SiteSetting.ai_summarization_enabled
        DiscourseAi::Summarization::Strategies::FoldContent.new(SiteSetting.ai_summarization_model)
      else
        nil
      end
    end

    class EntryPoint
      def inject_into(plugin)
        plugin.add_to_serializer(:current_user, :can_summarize) do
          scope.user.in_any_groups?(SiteSetting.ai_custom_summarization_allowed_groups_map)
        end

        plugin.add_to_serializer(:topic_view, :summarizable) do
          guardian.can_see_summary?(object.topic)
        end

        plugin.add_to_serializer(:web_hook_topic_view, :summarizable) do
          guardian.can_see_summary?(object.topic)
        end
      end
    end
  end
end
