# frozen_string_literal: true

module ::Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless bot_user = User.find_by(id: args[:bot_user_id])
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])
      persona_id = args[:persona_id]

      begin
        persona = DiscourseAi::AiBot::Personas::Persona.find_by(user: post.user, id: persona_id)
        raise DiscourseAi::AiBot::Bot::BOT_NOT_FOUND if persona.nil?

        bot = DiscourseAi::AiBot::Bot.as(bot_user, persona: persona.new)

        DiscourseAi::AiBot::Playground.new(bot).reply_to(post)
      rescue DiscourseAi::AiBot::Bot::BOT_NOT_FOUND
        Rails.logger.warn(
          "Bot not found for post #{post.id} - perhaps persona was deleted or bot was disabled",
        )
      end
    end
  end
end
