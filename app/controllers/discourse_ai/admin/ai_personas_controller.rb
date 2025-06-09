# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiPersonasController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      before_action :find_ai_persona, only: %i[edit update destroy create_user]

      def index
        ai_personas =
          AiPersona.ordered.map do |persona|
            # we use a special serializer here cause names and descriptions are
            # localized for system personas
            LocalizedAiPersonaSerializer.new(persona, root: false)
          end
        tools =
          DiscourseAi::Personas::Persona.all_available_tools.map do |tool|
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
          DiscourseAi::Configuration::LlmEnumerator.values_for_serialization(
            allowed_seeded_llm_ids: SiteSetting.ai_bot_allowed_seeded_models_map,
          )
        render json: {
                 ai_personas: ai_personas,
                 meta: {
                   tools: tools,
                   llms: llms,
                   settings: {
                     rag_images_enabled: SiteSetting.ai_rag_images_enabled,
                   },
                 },
               }
      end

      def new
      end

      def edit
        render json: LocalizedAiPersonaSerializer.new(@ai_persona)
      end

      def create
        ai_persona = AiPersona.new(ai_persona_params.except(:rag_uploads))
        if ai_persona.save
          RagDocumentFragment.link_target_and_uploads(ai_persona, attached_upload_ids)
          log_ai_persona_creation(ai_persona)

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
        # Capture initial state for logging
        initial_attributes = @ai_persona.attributes.dup

        if @ai_persona.update(ai_persona_params.except(:rag_uploads))
          RagDocumentFragment.update_target_uploads(@ai_persona, attached_upload_ids)
          log_ai_persona_update(@ai_persona, initial_attributes)

          render json: LocalizedAiPersonaSerializer.new(@ai_persona, root: false)
        else
          render_json_error @ai_persona
        end
      end

      def destroy
        # Capture persona details for logging before destruction
        persona_details = {
          persona_id: @ai_persona.id,
          name: @ai_persona.name,
          description: @ai_persona.description
        }

        if @ai_persona.destroy
          log_ai_persona_deletion(persona_details)
          head :no_content
        else
          render_json_error @ai_persona
        end
      end

      def stream_reply
        persona =
          AiPersona.find_by(name: params[:persona_name]) ||
            AiPersona.find_by(id: params[:persona_id])
        return render_json_error(I18n.t("discourse_ai.errors.persona_not_found")) if persona.nil?

        return render_json_error(I18n.t("discourse_ai.errors.persona_disabled")) if !persona.enabled

        if persona.default_llm.blank?
          return render_json_error(I18n.t("discourse_ai.errors.no_default_llm"))
        end

        if params[:query].blank?
          return render_json_error(I18n.t("discourse_ai.errors.no_query_specified"))
        end

        if !persona.user_id
          return render_json_error(I18n.t("discourse_ai.errors.no_user_for_persona"))
        end

        if !params[:username] && !params[:user_unique_id]
          return render_json_error(I18n.t("discourse_ai.errors.no_user_specified"))
        end

        user = nil

        if params[:username]
          user = User.find_by_username(params[:username])
          return render_json_error(I18n.t("discourse_ai.errors.user_not_found")) if user.nil?
        elsif params[:user_unique_id]
          user = stage_user
        end

        raise Discourse::NotFound if user.nil?

        topic_id = params[:topic_id].to_i
        topic = nil

        if topic_id > 0
          topic = Topic.find(topic_id)

          if topic.topic_allowed_users.where(user_id: user.id).empty?
            return render_json_error(I18n.t("discourse_ai.errors.user_not_allowed"))
          end
        end

        hijack = request.env["rack.hijack"]
        io = hijack.call

        DiscourseAi::AiBot::ResponseHttpStreamer.queue_streamed_reply(
          io: io,
          persona: persona,
          user: user,
          topic: topic,
          query: params[:query].to_s,
          custom_instructions: params[:custom_instructions].to_s,
          current_user: current_user,
        )
      end

      private

      AI_STREAM_CONVERSATION_UNIQUE_ID = "ai-stream-conversation-unique-id"

      def stage_user
        unique_id = params[:user_unique_id].to_s
        field = UserCustomField.find_by(name: AI_STREAM_CONVERSATION_UNIQUE_ID, value: unique_id)

        if field
          field.user
        else
          preferred_username = params[:preferred_username]
          username = UserNameSuggester.suggest(preferred_username || unique_id)

          user =
            User.new(
              username: username,
              email: "#{SecureRandom.hex}@invalid.com",
              staged: true,
              active: false,
            )
          user.custom_fields[AI_STREAM_CONVERSATION_UNIQUE_ID] = unique_id
          user.save!
          user
        end
      end

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
            :default_llm_id,
            :user_id,
            :max_context_posts,
            :vision_enabled,
            :vision_max_pixels,
            :rag_chunk_tokens,
            :rag_chunk_overlap_tokens,
            :rag_conversation_chunks,
            :rag_llm_model_id,
            :question_consolidator_llm_id,
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

        if response_format = params.dig(:ai_persona, :response_format)
          permitted[:response_format] = permit_response_format(response_format)
        end

        if examples = params.dig(:ai_persona, :examples)
          permitted[:examples] = permit_examples(examples)
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

      def permit_response_format(response_format)
        return [] if !response_format.is_a?(Array)

        response_format.map do |element|
          if element && element.is_a?(ActionController::Parameters)
            element.permit!
          else
            false
          end
        end
      end

      def permit_examples(examples)
        return [] if !examples.is_a?(Array)

        examples.map { |example_arr| example_arr.take(2).map(&:to_s) }
      end

      def log_ai_persona_creation(ai_persona)
        # Create basic entity details with important attributes
        log_details = {
          persona_id: ai_persona.id,
          persona_name: ai_persona.name,
          description: ai_persona.description
        }
        
        # Include basic configuration fields if present
        %w[enabled priority temperature top_p default_llm_id].each do |field|
          value = ai_persona.send(field) if ai_persona.respond_to?(field)
          log_details[field] = value if value.present?
        end
        
        # Handle system prompt specially (truncate if too long)
        if ai_persona.system_prompt.present?
          if ai_persona.system_prompt.length > 100
            log_details[:system_prompt] = ai_persona.system_prompt.truncate(100)
          else
            log_details[:system_prompt] = ai_persona.system_prompt
          end
        end
        
        # Add tools count separately as it's not a direct attribute
        log_details[:tools_count] = (ai_persona.tools || []).size
        
        # Add allowed_group_ids
        log_details[:allowed_group_ids] = ai_persona.allowed_group_ids if ai_persona.allowed_group_ids.present?
        
        # Use StaffActionLogger directly with the proper subject
        StaffActionLogger.new(current_user).log_custom("create_ai_persona", log_details.merge(subject: ai_persona.name))
      end

      def log_ai_persona_update(ai_persona, initial_attributes)
        # Create basic entity details
        log_details = {
          persona_id: ai_persona.id,
          persona_name: ai_persona.name
        }
        
        # Track simple changes
        %w[name description enabled priority system_prompt default_llm_id temperature top_p
           vision_enabled vision_max_pixels max_context_posts rag_chunk_tokens rag_chunk_overlap_tokens
           rag_conversation_chunks rag_llm_model_id question_consolidator_llm_id forced_tool_count
           allow_chat_channel_mentions allow_chat_direct_messages allow_topic_mentions allow_personal_messages].each do |field|
          
          if initial_attributes[field] != ai_persona.attributes[field]
            log_details["#{field}_changed"] = true
            
            # For large text fields, don't include the values
            if field == "system_prompt"
              log_details["#{field}_updated"] = true
            else 
              # For simple fields, show the before/after values
              initial_value = initial_attributes[field]
              current_value = ai_persona.attributes[field]
              log_details[field] = "#{initial_value} → #{current_value}"
            end
          end
        end
        
        # Check JSON fields
        %w[allowed_group_ids tools response_format examples].each do |field|
          if initial_attributes[field].to_s != ai_persona.attributes[field].to_s
            log_details["#{field}_changed"] = true
          end
        end
        
        # Only log if there are actual changes
        if log_details.keys.any? { |k| k.to_s.end_with?("_changed") }
          # Use StaffActionLogger directly with the proper subject
          StaffActionLogger.new(current_user).log_custom("update_ai_persona", log_details.merge(subject: ai_persona.name))
        end
      end

      def log_ai_persona_deletion(persona_details)
        # Use StaffActionLogger directly with the proper subject
        StaffActionLogger.new(current_user).log_custom("delete_ai_persona", persona_details.merge(subject: persona_details[:name]))
      end
    end
  end
end
