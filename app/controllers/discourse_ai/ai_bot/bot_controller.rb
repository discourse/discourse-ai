# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class BotController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login

      def stop_streaming_response
        post = Post.find(params[:post_id])
        guardian.ensure_can_see!(post)

        Discourse.redis.del("gpt_cancel:#{post.id}")

        render json: {}, status: 200
      end
    end
  end
end
