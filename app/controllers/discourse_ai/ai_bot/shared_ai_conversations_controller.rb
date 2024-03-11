# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class SharedAiConversationsController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login only: %i[create update destroy]
      before_action :ensure_allowed_create!, only: %i[create]
      before_action :ensure_allowed_destroy!, only: %i[destroy]
      before_action :ensure_allowed_preview!, only: %i[preview]
      before_action :require_site_settings!

      skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required, only: %i[show]

      def create
        shared_conversation = SharedAiConversation.share_conversation(current_user, @topic)

        if shared_conversation.persisted?
          render json: { share_key: shared_conversation.share_key }
        else
          render json: { error: "Failed to share the conversation" }, status: :unprocessable_entity
        end
      end

      def destroy
        @shared_conversation.destroy
        render json: { message: "Conversation share deleted successfully" }
      end

      def show
        @shared_conversation = SharedAiConversation.find_by(share_key: params[:share_key])

        if @shared_conversation.present?
          expires_in 1.minute, public: true
          response.headers["X-Robots-Tag"] = "noindex"

          # render json for json reqs
          if request.format.json?
            posts =
              @shared_conversation.populated_posts.map do |post|
                {
                  id: post.id,
                  cooked: post.cooked,
                  username: post.user.username,
                  created_at: post.created_at,
                }
              end
            render json: {
                     llm_name: @shared_conversation.llm_name,
                     share_key: @shared_conversation.share_key,
                     title: @shared_conversation.title,
                     posts: posts,
                   }
          else
            render "show", layout: false
          end
        else
          raise Discourse::NotFound
        end
      end

      def preview
        data = SharedAiConversation.build_conversation_data(@topic, include_usernames: true)
        data[:error] = @error if @error
        data[:share_key] = @shared_conversation.share_key if @shared_conversation
        data[:topic_id] = @topic.id
        render json: data
      end

      private

      def require_site_settings!
        if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_bot_allow_public_sharing ||
             !SiteSetting.ai_bot_enabled
          raise Discourse::NotFound
        end
      end

      def ensure_allowed_preview!
        @topic = Topic.find_by(id: params[:topic_id])
        raise Discourse::NotFound if !@topic

        @shared_conversation = SharedAiConversation.find_by(topic_id: params[:topic_id])

        @error = DiscourseAi::AiBot::EntryPoint.ai_share_error(@topic, guardian)
        if @error == :not_allowed
          raise Discourse::InvalidAccess.new(
                  nil,
                  nil,
                  custom_message: "discourse_ai.share_ai.errors.#{@error}",
                )
        end
      end

      def ensure_allowed_destroy!
        @shared_conversation = SharedAiConversation.find_by(share_key: params[:share_key])

        raise Discourse::InvalidAccess.new if @shared_conversation.blank?

        if @shared_conversation.user_id != current_user.id && !current_user.admin?
          raise Discourse::InvalidAccess.new
        end
      end

      def ensure_allowed_create!
        @topic = Topic.find_by(id: params[:topic_id])
        error = DiscourseAi::AiBot::EntryPoint.ai_share_error(@topic, guardian)
        if error
          raise Discourse::InvalidAccess.new(
                  nil,
                  nil,
                  custom_message: "discourse_ai.share_ai.errors.#{error}",
                )
        end
      end
    end
  end
end
