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

      class << self
        POOL_SIZE = 10
        def thread_pool
          @thread_pool ||=
            Concurrent::CachedThreadPool.new(min_threads: 0, max_threads: POOL_SIZE, idletime: 30)
        end

        def queue_reply(&block)
          # think about a better way to handle cross thread connections
          if Rails.env.test?
            block.call
            return
          end

          db = RailsMultisite::ConnectionManagement.current_db
          thread_pool.post do
            begin
              RailsMultisite::ConnectionManagement.with_connection(db) { block.call }
            rescue StandardError => e
              Discourse.warn_exception(e, message: "Discourse AI: Unable to stream reply")
            end
          end
        end
      end

      CRLF = "\r\n"

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
        post = nil

        if topic_id > 0
          topic = Topic.find(topic_id)

          raise Discourse::NotFound if topic.nil?

          if topic.topic_allowed_users.where(user_id: user.id).empty?
            return render_json_error(I18n.t("discourse_ai.errors.user_not_allowed"))
          end

          post =
            PostCreator.create!(
              user,
              topic_id: topic_id,
              raw: params[:query],
              skip_validations: true,
            )
        else
          post =
            PostCreator.create!(
              user,
              title: I18n.t("discourse_ai.ai_bot.default_pm_prefix"),
              raw: params[:query],
              archetype: Archetype.private_message,
              target_usernames: "#{user.username},#{persona.user.username}",
              skip_validations: true,
            )

          topic = post.topic
        end

        hijack = request.env["rack.hijack"]
        io = hijack.call

        user = current_user

        self.class.queue_reply do
          begin
            io.write "HTTP/1.1 200 OK"
            io.write CRLF
            io.write "Content-Type: text/plain; charset=utf-8"
            io.write CRLF
            io.write "Transfer-Encoding: chunked"
            io.write CRLF
            io.write "Cache-Control: no-cache, no-store, must-revalidate"
            io.write CRLF
            io.write "Connection: close"
            io.write CRLF
            io.write "X-Accel-Buffering: no"
            io.write CRLF
            io.write "X-Content-Type-Options: nosniff"
            io.write CRLF
            io.write CRLF
            io.flush

            persona_class =
              DiscourseAi::AiBot::Personas::Persona.find_by(id: persona.id, user: user)
            bot = DiscourseAi::AiBot::Bot.as(persona.user, persona: persona_class.new)

            topic_id = topic.id
            data =
              { topic_id: topic.id, bot_user_id: persona.user.id, persona_id: persona.id }.to_json +
                "\n\n"

            io.write data.bytesize.to_s(16)
            io.write CRLF
            io.write data
            io.write CRLF

            DiscourseAi::AiBot::Playground
              .new(bot)
              .reply_to(post) do |partial|
                next if partial.length == 0

                data = { partial: partial }.to_json + "\n\n"

                data.force_encoding("UTF-8")

                io.write data.bytesize.to_s(16)
                io.write CRLF
                io.write data
                io.write CRLF
                io.flush
              end

            io.write "0"
            io.write CRLF
            io.write CRLF

            io.flush
            io.done
          rescue StandardError => e
            # make it a tiny bit easier to debug in dev, this is tricky
            # multi-threaded code that exhibits various limitations in rails
            p e if Rails.env.development?
            Discourse.warn_exception(e, message: "Discourse AI: Unable to stream reply")
          ensure
            io.close
          end
        end
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
