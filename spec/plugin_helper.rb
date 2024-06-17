# frozen_string_literal: true

module DiscourseAi::ChatBotHelper
  def toggle_enabled_bots(bots: [])
    LlmModel.update_all(enabled_chat_bot: false)
    bots.each { |b| b.update!(enabled_chat_bot: true) }
    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots
  end
end

RSpec.configure { |c| c.include DiscourseAi::ChatBotHelper }
