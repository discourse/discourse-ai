# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiPersonasController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      before_action :find_ai_persona, only: %i[show update destroy create_user]

      def index
        ai_personas =
          AiPersona.ordered.map do |persona|
            # we use a special serializer here cause names and descriptions are
            # localized for system personas
            LocalizedAiPersonaSerializer.new(persona, root: false)
          end
        tools =
          DiscourseAi::AiBot::Personas::Persona.all_available_tools.map do |tool|
            AiToolSerializer.new(tool, root: false)
          end
        llms =
          DiscourseAi::Configuration::LlmEnumerator.values.map do |hash|
            { id: hash[:value], name: hash[:name] }
          end
        render json: { ai_personas: ai_personas, meta: { commands: tools, llms: llms } }
      end

      def show
        render json: LocalizedAiPersonaSerializer.new(@ai_persona)
      end

      def create
        ai_persona = AiPersona.new(ai_persona_params)
        if ai_persona.save
          render json: { ai_persona: ai_persona }, status: :created
        else
          render_json_error ai_persona
        end
      end

      def create_user
        user = @ai_persona.create_user!
        render json: BasicUserSerializer.new(user, root: "user")
      end

      def update
        if @ai_persona.update(ai_persona_params)
          render json: @ai_persona
        else
          render_json_error @ai_persona
        end
      end

      def destroy
        if @ai_persona.destroy
          head :no_content
        else
          render_json_error @ai_persona
        end
      end

      private

      def find_ai_persona
        @ai_persona = AiPersona.find(params[:id])
      end

      def ai_persona_params
        permitted =
          params.require(:ai_persona).permit(
            :name,
            :description,
            :enabled,
            :system_prompt,
            :priority,
            :top_p,
            :temperature,
            :default_llm,
            :user_id,
            :mentionable,
            :max_context_posts,
            allowed_group_ids: [],
          )

        if commands = params.dig(:ai_persona, :commands)
          permitted[:commands] = permit_commands(commands)
        end

        permitted
      end

      def permit_commands(commands)
        return [] if !commands.is_a?(Array)

        commands.filter_map do |command, options|
          break nil if !command.is_a?(String)
          options&.permit! if options && options.is_a?(ActionController::Parameters)

          if options
            [command, options]
          else
            command
          end
        end
      end
    end
  end
end
