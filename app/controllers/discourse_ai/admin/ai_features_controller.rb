# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiFeaturesController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        render json: persona_backed_features
      end

      def edit
        raise Discourse::InvalidParameters.new(:id) if params[:id].blank?
        render json: find_feature_by_id(params[:id].to_i)
      end

      def update
      end

      def destroy
      end

      private

      # Eventually we may move this to an active record model
      def persona_backed_features
        [
          {
            id: 1,
            name: "Summaries",
            description:
              "Makes a summarization button available that allows visitors to summarize topics.",
            persona:
              serialize_data(
                AiPersona.find_by(id: SiteSetting.ai_summarization_persona),
                AiFeaturesPersonaSerializer,
                root: false,
              ),
            enabled: SiteSetting.ai_summarization_enabled,
            enable_setting: {
              type: SiteSetting.ai_summarization_enabled.class,
              value: "ai_summarization_enabled",
            },
          },
          {
            id: 2,
            name: "Short Summaries",
            description: "Adds the ability to view short summaries of topics on the topic list.",
            persona:
              serialize_data(
                AiPersona.find_by(id: SiteSetting.ai_summary_gists_persona),
                AiFeaturesPersonaSerializer,
                root: false,
              ),
            enabled: SiteSetting.ai_summary_gists_enabled,
            enable_setting: {
              type: SiteSetting.ai_summary_gists_enabled.class,
              value: "ai_summary_gists_enabled",
            },
          },
          {
            id: 3,
            name: "Discobot Discoveries",
            description: "Enhances search experience by providing AI-generated answers to queries.",
            persona:
              serialize_data(
                AiPersona.find_by(id: SiteSetting.ai_bot_discover_persona),
                AiFeaturesPersonaSerializer,
                root: false,
              ),
            enabled: SiteSetting.ai_bot_enabled,
            enable_setting: {
              type: SiteSetting.ai_bot_enabled.class,
              value: "ai_bot_enabled",
            },
          },
          {
            id: 4,
            name: "Discord Search",
            description: "Adds the ability to search Discord channels.",
            persona:
              serialize_data(
                AiPersona.find_by(id: SiteSetting.ai_discord_search_persona),
                AiFeaturesPersonaSerializer,
                root: false,
              ),
            enabled: SiteSetting.ai_discord_app_id.present?,
            enable_setting: {
              type: SiteSetting.ai_discord_app_id.class,
              value: "ai_discord_app_id",
            },
          },
        ]
      end

      def find_feature_by_id(id)
        lookup = persona_backed_features.index_by { |feature| feature[:id] }
        lookup[id]
      end
    end
  end
end
