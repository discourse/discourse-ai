# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiPersonasController < ::Admin::AdminController
      before_action :find_ai_persona, only: %i[show update destroy]

      def index
        ai_personas = AiPersona.all
        render json: ai_personas
      end

      def show
        render json: { ai_persona: @ai_persona }
      end

      def create
        ai_persona = AiPersona.new(ai_persona_params)
        if ai_persona.save
          render json: ai_persona, status: :created
        else
          render json: ai_persona.errors, status: :unprocessable_entity
        end
      end

      def update
        if @ai_persona.update(ai_persona_params)
          render json: @ai_persona
        else
          render json: @ai_persona.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @ai_persona.destroy
        head :no_content
      end

      private

      def find_ai_persona
        @ai_persona = AiPersona.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "AiPersona not found" }, status: :not_found
      end

      def ai_persona_params
        params.require(:ai_persona).permit(
          :name,
          :description,
          :enabled,
          :system_prompt,
          :enabled,
          allowed_group_ids: [],
          commands: [],
        )
      end
    end
  end
end
