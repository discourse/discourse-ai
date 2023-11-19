# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiPersonasController < ::Admin::AdminController
      before_action :find_ai_persona, only: %i[show update destroy]

      def index
        ai_personas =
          AiPersona.ordered.map { |persona| AiPersonaSerializer.new(persona, root: false) }
        commands =
          DiscourseAi::AiBot::Personas::Persona.all_available_commands.map do |command|
            { id: command.to_s.split("::").last, name: command.name }
          end
        render json: { ai_personas: ai_personas, meta: { commands: commands } }
      end

      def show
        render json: { ai_persona: @ai_persona }
      end

      def create
        ai_persona = AiPersona.new(ai_persona_params)
        if ai_persona.save
          render json: { ai_persona: ai_persona }, status: :created
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
        if @ai_persona.errors.present?
          render json: @ai_persona.errors, status: :unprocessable_entity
        else
          head :no_content
        end
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
          :priority,
          allowed_group_ids: [],
          commands: [],
        )
      end
    end
  end
end
