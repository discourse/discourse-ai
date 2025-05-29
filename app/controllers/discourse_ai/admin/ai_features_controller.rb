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

      private

      def serialize_features(features)
        features.map { |feature| feature.merge(agent: serialize_agent(feature[:agent])) }
      end

      def serialize_feature(feature)
        return nil if feature.blank?

        feature.merge(agent: serialize_agent(feature[:agent]))
      end

      def serialize_agent(agent)
        return nil if agent.blank?

        serialize_data(agent, AiFeaturesAgentSerializer, root: false)
      end
    end
  end
end
