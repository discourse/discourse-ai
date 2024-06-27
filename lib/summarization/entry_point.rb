# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def inject_into(plugin)
        plugin.add_to_serializer(:current_user, :can_summarize) do
          scope.user.in_any_groups?(SiteSetting.ai_custom_summarization_allowed_groups_map)
        end

        plugin.add_to_serializer(:topic_view, :summarizable) do
          DiscourseAi::Summarization::Models::Base.can_see_summary?(object.topic, scope.user)
        end

        plugin.add_to_serializer(:web_hook_topic_view, :summarizable) do
          DiscourseAi::Summarization::Models::Base.can_see_summary?(object.topic, scope.user)
        end
      end
    end
  end
end
