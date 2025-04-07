# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiFeaturesController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        render json: serialize_features(DiscourseAi::Features.features)
      end

      def edit
        raise Discourse::InvalidParameters.new(:id) if params[:id].blank?
        render json: serialize_feature(DiscourseAi::Features.find_feature_by_id(params[:id].to_i))
      end

      def update
        raise Discourse::InvalidParameters.new(:id) if params[:id].blank?
        raise Discourse::InvalidParameters.new(:ai_feature) if params[:ai_feature].blank?
        if params[:ai_feature][:persona_id].blank?
          raise Discourse::InvalidParameters.new(:persona_id)
        end
        raise Discourse::InvalidParameters.new(:enabled) if params[:ai_feature][:enabled].nil?

        feature = DiscourseAi::Features.find_feature_by_id(params[:id].to_i)
        enable_value = params[:ai_feature][:enabled]
        persona_id = params[:ai_feature][:persona_id]

        SiteSetting.set_and_log(feature[:enable_setting][:name], enable_value, guardian.user)
        SiteSetting.set_and_log(feature[:persona_setting][:name], persona_id, guardian.user)

        render json: serialize_feature(DiscourseAi::Features.find_feature_by_id(params[:id].to_i))
      end

      private

      def serialize_features(features)
        features.map { |feature| feature.merge(persona: serialize_persona(feature[:persona])) }
      end

      def serialize_feature(feature)
        return nil if feature.blank?

        feature.merge(persona: serialize_persona(feature[:persona]))
      end

      def serialize_persona(persona)
        return nil if persona.blank?

        serialize_data(persona, AiFeaturesPersonaSerializer, root: false)
      end
    end
  end
end
