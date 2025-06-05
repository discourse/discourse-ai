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
        render json: serialize_module(DiscourseAi::Features.find_module_by_id(params[:id].to_i))
      end

      private

      def serialize_features(modules)
        modules.map { |a_module| serialize_module(a_module) }
      end

      def serialize_module(a_module)
        return nil if a_module.blank?

        a_module.merge(
          features:
            a_module[:features].map { |f| f.merge(persona: serialize_persona(f[:persona])) },
        )
      end

      def serialize_persona(persona)
        return nil if persona.blank?

        serialize_data(persona, AiFeaturesPersonaSerializer, root: false)
      end
    end
  end
end
