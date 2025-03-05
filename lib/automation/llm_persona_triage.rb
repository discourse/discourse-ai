# frozen_string_literal: true
module DiscourseAi
  module Automation
    module LlmPersonaTriage
      def self.handle(post:, persona_id:, whisper: false, automation: nil)
        ai_persona = AiPersona.find_by(id: persona_id)
        return if ai_persona.nil?

        persona_class = ai_persona.class_instance
        persona = persona_class.new

        bot_user = ai_persona.user
        return if bot_user.nil?

        bot = DiscourseAi::AiBot::Bot.as(bot_user, persona: persona)
        playground = DiscourseAi::AiBot::Playground.new(bot)

        playground.reply_to(post, whisper: whisper, context_style: :topic)
      rescue => e
        Rails.logger.error("Error in LlmPersonaTriage: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e if Rails.env.test?
        nil
      end
    end
  end
end
