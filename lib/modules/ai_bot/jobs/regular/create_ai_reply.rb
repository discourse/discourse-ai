# frozen_string_literal: true

module ::Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless bot_user = User.find_by(id: args[:bot_user_id])
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])

      kwargs = {}
      kwargs[:user] = post.user
      if persona_id = post.topic.custom_fields["ai_persona_id"]
        kwargs[:persona_id] = persona_id.to_i
      else
        kwargs[:persona_name] = post.topic.custom_fields["ai_persona"]
      end

      begin
        bot = DiscourseAi::AiBot::Bot.as(bot_user, **kwargs)
        bot.reply_to(post)
      rescue DiscourseAi::AiBot::Bot::BOT_NOT_FOUND
        Rails.logger.warn(
          "Bot not found for post #{post.id} - perhaps persona was deleted or bot was disabled",
        )
      end
    end
  end
end
