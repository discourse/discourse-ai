# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiFeaturesController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        render json: persona_backed_features
      end

      def edit
      end

      def update
      end

      def destroy
      end

      private

      # Eventually we may move this to an active record model
      def persona_backed_features
        # TODO: WIP just getting data rn, will cleanup AiPersona call later...
        [
          {
            name: "Summaries",
            description:
              "Makes a summarization button available that allows visitors to summarize topics.",
            # persona: AiPersona.find_by(id: SiteSetting.ai_summarization_persona),
            persona: "Foo",
            enabled: SiteSetting.ai_summarization_enabled,
          },
          {
            name: "Short Summaries",
            description: "Adds the ability to view short summaries of topics on the topic list.",
            # persona: AiPersona.find_by(id: SiteSetting.ai_summary_gists_persona),
            persona: "Bar",
            enabled: SiteSetting.ai_summary_gists_enabled,
          },
          {
            name: "Discobot Discoveries",
            description: "",
            # persona: AiPersona.find_by(id: SiteSetting.ai_bot_discover_persona),
            persona: "Baz",
            enabled: SiteSetting.ai_bot_enabled,
          },
          {
            name: "Discord Search",
            description: "Adds the ability to search Discord channels.",
            # persona: AiPersona.find_by(id: SiteSetting.ai_discord_search_persona),
            persona: "Qux",
            enabled: "",
          },
        ]
      end
    end
  end
end
