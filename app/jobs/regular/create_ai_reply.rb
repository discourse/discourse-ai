# frozen_string_literal: true

module ::Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless bot_user = User.find_by(id: args[:bot_user_id])
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])

      begin
        persona = nil
        if persona_id = post.topic.custom_fields["ai_persona_id"]
          persona =
            DiscourseAi::AiBot::Personas::Persona.find_by(user: post.user, id: persona_id.to_i)
          raise DiscourseAi::AiBot::Bot::BOT_NOT_FOUND if persona.nil?
        end

        if !persona && persona_name = post.topic.custom_fields["ai_persona"]
          persona =
            DiscourseAi::AiBot::Personas::Persona.find_by(user: post.user, name: persona_name)
          raise DiscourseAi::AiBot::Bot::BOT_NOT_FOUND if persona.nil?
        end

        persona ||= DiscourseAi::AiBot::Personas::General

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
