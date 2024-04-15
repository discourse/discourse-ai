# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class BotController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login

      def show_debug_info
        post = Post.find(params[:post_id])
        guardian.ensure_can_debug_ai_bot_conversation!(post)

        debug_info = AiApiAuditLog.where(post_id: post.id).order(created_at: :desc).first

        render json: debug_info, status: 200
      end

      def stop_streaming_response
        post = Post.find(params[:post_id])
        guardian.ensure_can_see!(post)

        Discourse.redis.del("gpt_cancel:#{post.id}")

        render json: {}, status: 200
      end

      def show_bot_username
        bot_user_id = DiscourseAi::AiBot::EntryPoint.map_bot_model_to_user_id(params[:username])
        raise Discourse::InvalidParameters.new(:username) if !bot_user_id

        bot_username_lower = User.find(bot_user_id).username_lower

        render json: { bot_username: bot_username_lower }, status: 200
      end
    end
  end
end
