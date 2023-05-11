# frozen_string_literal: true

module ::Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless bot_user = User.find_by(id: args[:bot_user_id])
      return unless bot = DiscourseAi::AiBot::Bot.as(bot_user)
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])

      bot.reply_to(post)
    end
  end
end
