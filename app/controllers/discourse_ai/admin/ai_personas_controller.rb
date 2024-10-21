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
        AiTool
          .where(enabled: true)
          .each do |tool|
            tools << {
              id: "custom-#{tool.id}",
              name:
                I18n.t(
                  "discourse_ai.tools.custom_name",
                  name: tool.name.capitalize,
                  tool_name: tool.tool_name,
                ),
            }
          end
        llms =
          DiscourseAi::Configuration::LlmEnumerator.values.map do |hash|
            { id: hash[:value], name: hash[:name] }
          end
        render json: { ai_personas: ai_personas, meta: { tools: tools, llms: llms } }
      end

      def show
        render json: LocalizedAiPersonaSerializer.new(@ai_persona)
      end

      def create
        ai_persona = AiPersona.new(ai_persona_params.except(:rag_uploads))
        if ai_persona.save
          RagDocumentFragment.link_target_and_uploads(ai_persona, attached_upload_ids)

          render json: {
                   ai_persona: LocalizedAiPersonaSerializer.new(ai_persona, root: false),
                 },
                 status: :created
        else
          render_json_error ai_persona
        end
      end

      def create_user
        user = @ai_persona.create_user!
        render json: BasicUserSerializer.new(user, root: "user")
      end

      def update
        if @ai_persona.update(ai_persona_params.except(:rag_uploads))
          RagDocumentFragment.update_target_uploads(@ai_persona, attached_upload_ids)

          render json: LocalizedAiPersonaSerializer.new(@ai_persona, root: false)
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

      def attached_upload_ids
        ai_persona_params[:rag_uploads].to_a.map { |h| h[:id] }
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
            :max_context_posts,
            :vision_enabled,
            :vision_max_pixels,
            :rag_chunk_tokens,
            :rag_chunk_overlap_tokens,
            :rag_conversation_chunks,
            :question_consolidator_llm,
            :allow_chat_channel_mentions,
            :allow_chat_direct_messages,
            :allow_topic_mentions,
            :allow_personal_messages,
            :tool_details,
            :forced_tool_count,
            :force_default_llm,
            allowed_group_ids: [],
            rag_uploads: [:id],
          )

        if tools = params.dig(:ai_persona, :tools)
          permitted[:tools] = permit_tools(tools)
        end

        permitted
      end

      def permit_tools(tools)
        return [] if !tools.is_a?(Array)

        tools.filter_map do |tool, options, force_tool|
          break nil if !tool.is_a?(String)
          options&.permit! if options && options.is_a?(ActionController::Parameters)

          # this is simpler from a storage perspective, 1 way to store tools
          [tool, options, !!force_tool]
        end
      end
    end
  end
end
