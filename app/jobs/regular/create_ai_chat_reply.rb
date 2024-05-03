# frozen_string_literal: true

module ::Jobs
  class CreateAiChatReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      # 2 calls cause we need channel later
      channel = ::Chat::Channel.find_by(id: args[:channel_id])
      return if channel.blank?

      message = ::Chat::Message.find_by(id: args[:message_id])
      return if message.blank?

      personaClass =
        DiscourseAi::AiBot::Personas::Persona.find_by(id: args[:persona_id], user: message.user)
      return if personaClass.blank?

      model_without_provider = personaClass.default_llm.split(":").last
      bot_user_id = DiscourseAi::AiBot::EntryPoint.map_bot_model_to_user_id(model_without_provider)
      bot = DiscourseAi::AiBot::Bot.as(User.find(bot_user_id), persona: personaClass.new)

      DiscourseAi::AiBot::Playground.new(bot).reply_to_chat_message(message, channel)
    end
  end
end
