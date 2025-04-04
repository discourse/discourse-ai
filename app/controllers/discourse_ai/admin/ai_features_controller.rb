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
        raise Discourse::InvalidParameters.new(:id) if params[:id].blank?
        raise Discourse::InvalidParameters.new(:ai_feature) if params[:ai_feature].blank?
        if params[:ai_feature][:persona_id].blank?
          raise Discourse::InvalidParameters.new(:persona_id)
        end
        raise Discourse::InvalidParameters.new(:enabled) if params[:ai_feature][:enabled].nil?

        feature = find_feature_by_id(params[:id].to_i)
        enable_value = params[:ai_feature][:enabled]
        persona_id = params[:ai_feature][:persona_id]

        SiteSetting.set_and_log(feature[:enable_setting][:name], enable_value, guardian.user)
        SiteSetting.set_and_log(feature[:persona_setting][:name], persona_id, guardian.user)

        render json: find_feature_by_id(params[:id].to_i)
      end

      private

      # Eventually we may move this all to an active record model
      # but for now we are just using a hash
      # to store the features and their corresponding settings
      def feature_config
        [
          {
            id: 1,
            name_key: "discourse_ai.features.summarization.name",
            description_key: "discourse_ai.features.summarization.description",
            persona_setting_name: "ai_summarization_persona",
            enable_setting_name: "ai_summarization_enabled",
          },
          {
            id: 2,
            name_key: "discourse_ai.features.gists.name",
            description_key: "discourse_ai.features.gists.description",
            persona_setting_name: "ai_summary_gists_persona",
            enable_setting_name: "ai_summary_gists_enabled",
          },
          {
            id: 3,
            name_key: "discourse_ai.features.discoveries.name",
            description_key: "discourse_ai.features.discoveries.description",
            persona_setting_name: "ai_bot_discover_persona",
            enable_setting_name: "ai_bot_enabled",
          },
          {
            id: 4,
            name_key: "discourse_ai.features.discord_search.name",
            description_key: "discourse_ai.features.discord_search.description",
            persona_setting_name: "ai_discord_search_persona",
            enable_setting_name: "ai_discord_search_enabled",
          },
        ]
      end

      def persona_backed_features
        feature_config.map do |feature|
          {
            id: feature[:id],
            name: I18n.t(feature[:name_key]),
            description: I18n.t(feature[:description_key]),
            persona:
              serialize_data(
                AiPersona.find_by(id: SiteSetting.get(feature[:persona_setting_name])),
                AiFeaturesPersonaSerializer,
                root: false,
              ),
            persona_setting: {
              name: feature[:persona_setting_name],
              value: SiteSetting.get(feature[:persona_setting_name]),
              type: SiteSetting.type_supervisor.get_type(feature[:persona_setting_name]),
            },
            enable_setting: {
              name: feature[:enable_setting_name],
              value: SiteSetting.get(feature[:enable_setting_name]),
              type: SiteSetting.type_supervisor.get_type(feature[:enable_setting_name]),
            },
          }
        end
      end

      def find_feature_by_id(id)
        lookup = persona_backed_features.index_by { |feature| feature[:id] }
        lookup[id]
      end
    end
  end
end
