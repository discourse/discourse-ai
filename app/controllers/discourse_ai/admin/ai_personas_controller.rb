# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiPersonasController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      before_action :find_ai_persona,
                    only: %i[show update destroy create_user indexing_status_check]

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
              name: I18n.t("discourse_ai.tools.custom_name", name: tool.name.capitalize),
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

      def upload_file
        file = params[:file] || params[:files].first

        if !SiteSetting.ai_embeddings_enabled?
          raise Discourse::InvalidAccess.new("Embeddings not enabled")
        end

        validate_extension!(file.original_filename)
        validate_file_size!(file.tempfile.size)

        hijack do
          upload =
            UploadCreator.new(
              file.tempfile,
              file.original_filename,
              type: "discourse_ai_rag_upload",
              skip_validations: true,
            ).create_for(current_user.id)

          if upload.persisted?
            render json: UploadSerializer.new(upload)
          else
            render json: failed_json.merge(errors: upload.errors.full_messages), status: 422
          end
        end
      end

      def indexing_status_check
        render json: RagDocumentFragment.indexing_status(@ai_persona, @ai_persona.uploads)
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
            :mentionable,
            :max_context_posts,
            :vision_enabled,
            :vision_max_pixels,
            :rag_chunk_tokens,
            :rag_chunk_overlap_tokens,
            :rag_conversation_chunks,
            :question_consolidator_llm,
            :allow_chat,
            :tool_details,
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

        tools.filter_map do |tool, options|
          break nil if !tool.is_a?(String)
          options&.permit! if options && options.is_a?(ActionController::Parameters)

          if options
            [tool, options]
          else
            tool
          end
        end
      end

      def validate_extension!(filename)
        extension = File.extname(filename)[1..-1] || ""
        authorized_extensions = %w[txt md]
        if !authorized_extensions.include?(extension)
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "upload.unauthorized",
                    authorized_extensions: authorized_extensions.join(" "),
                  ),
                )
        end
      end

      def validate_file_size!(filesize)
        max_size_bytes = 20.megabytes
        if filesize > max_size_bytes
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "upload.attachments.too_large_humanized",
                    max_size: ActiveSupport::NumberHelper.number_to_human_size(max_size_bytes),
                  ),
                )
        end
      end
    end
  end
end
