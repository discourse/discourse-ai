# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiAgentsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      before_action :find_ai_agent, only: %i[edit update destroy create_user]

      def index
        ai_agents =
          AiAgent.ordered.map do |agent|
            # we use a special serializer here cause names and descriptions are
            # localized for system agents
            LocalizedAiAgentSerializer.new(agent, root: false)
          end
        tools =
          DiscourseAi::Agents::Agent.all_available_tools.map do |tool|
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
                 ai_agents: ai_agents,
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
        render json: LocalizedAiAgentSerializer.new(@ai_agent)
      end

      def create
        ai_agent = AiAgent.new(ai_agent_params.except(:rag_uploads))
        if ai_agent.save
          RagDocumentFragment.link_target_and_uploads(ai_agent, attached_upload_ids)

          render json: {
                   ai_agent: LocalizedAiAgentSerializer.new(ai_agent, root: false),
                 },
                 status: :created
        else
          render_json_error ai_agent
        end
      end

      def create_user
        user = @ai_agent.create_user!
        render json: BasicUserSerializer.new(user, root: "user")
      end

      def update
        if @ai_agent.update(ai_agent_params.except(:rag_uploads))
          RagDocumentFragment.update_target_uploads(@ai_agent, attached_upload_ids)

          render json: LocalizedAiAgentSerializer.new(@ai_agent, root: false)
        else
          render_json_error @ai_agent
        end
      end

      def destroy
        if @ai_agent.destroy
          head :no_content
        else
          render_json_error @ai_agent
        end
      end

      def stream_reply
        agent =
          AiAgent.find_by(name: params[:agent_name]) ||
            AiAgent.find_by(id: params[:agent_id])
        return render_json_error(I18n.t("discourse_ai.errors.agent_not_found")) if agent.nil?

        return render_json_error(I18n.t("discourse_ai.errors.agent_disabled")) if !agent.enabled

        if agent.default_llm.blank?
          return render_json_error(I18n.t("discourse_ai.errors.no_default_llm"))
        end

        if params[:query].blank?
          return render_json_error(I18n.t("discourse_ai.errors.no_query_specified"))
        end

        if !agent.user_id
          return render_json_error(I18n.t("discourse_ai.errors.no_user_for_agent"))
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
          agent: agent,
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

      def find_ai_agent
        @ai_agent = AiAgent.find(params[:id])
      end

      def attached_upload_ids
        ai_agent_params[:rag_uploads].to_a.map { |h| h[:id] }
      end

      def ai_agent_params
        permitted =
          params.require(:ai_agent).permit(
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
            :allow_agentl_messages,
            :tool_details,
            :forced_tool_count,
            :force_default_llm,
            allowed_group_ids: [],
            rag_uploads: [:id],
          )

        if tools = params.dig(:ai_agent, :tools)
          permitted[:tools] = permit_tools(tools)
        end

        if response_format = params.dig(:ai_agent, :response_format)
          permitted[:response_format] = permit_response_format(response_format)
        end

        if examples = params.dig(:ai_agent, :examples)
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
    end
  end
end
