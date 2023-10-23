# frozen_string_literal: true

module DiscourseAi::AiBot::SiteSettingsExtension
  module ClassMethods
    def ai_bot_enabled=(val)
      super(val)
      DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots
    end

    def ai_bot_enabled_chat_bots=(val)
      super(val)
      DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots
    end
  end

  def self.enable_or_disable_ai_bots
    enabled_bots = SiteSetting.ai_bot_enabled_chat_bots.split("|")
    enabled_bots = [] if !SiteSetting.ai_bot_enabled
    DiscourseAi::AiBot::EntryPoint::BOTS.each do |id, bot_name, name|
      active = enabled_bots.include?(name)
      user = User.find_by(id: id)

      if active
        if !user
          user =
            User.new(
              id: id,
              email: "no_email_#{name}",
              name: bot_name.titleize,
              username: UserNameSuggester.suggest(bot_name),
              active: true,
              approved: true,
              admin: true,
              moderator: true,
              trust_level: TrustLevel[4],
            )
          user.save!(validate: false)
        else
          user.update!(active: true)
        end
      elsif !active && user
        # will include deleted
        has_posts = DB.query_single("SELECT 1 FROM posts WHERE user_id = #{id} LIMIT 1").present?

        if has_posts
          user.update!(active: false) if user.active
        else
          user.destroy
        end
      end
    end
  end
end

class ::SiteSetting
  class << self
    prepend DiscourseAi::AiBot::SiteSettingsExtension::ClassMethods
  end
end
