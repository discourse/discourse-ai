# frozen_string_literal: true

module DiscourseAi::AiBot::SiteSettingsExtension
  FIRST_BOT_USER_ID = -1200

  def self.enable_or_disable_ai_bots
    enabled_bots = SiteSetting.ai_bot_enabled_chat_bots_map
    enabled_bots = [] if !SiteSetting.ai_bot_enabled

    LlmModel.find_each do |llm_model|
      bot_name = llm_model.bot_username
      next if bot_name == "fake" && Rails.env.production?

      active = enabled_bots.include?(llm_model.name)
      user = llm_model.user

      if active
        if !user
          id = DB.query_single(<<~SQL).first
            SELECT min(id) - 1 FROM users
          SQL

          user =
            User.new(
              id: [FIRST_BOT_USER_ID, id].min,
              email: "no_email_#{bot_name}",
              name: bot_name.titleize,
              username: UserNameSuggester.suggest(bot_name),
              active: true,
              approved: true,
              admin: true,
              moderator: true,
              trust_level: TrustLevel[4],
            )
          user.save!(validate: false)
          llm_model.update!(user: user)
        else
          user.update!(active: true)
        end
      elsif !active && user
        # will include deleted
        has_posts =
          DB.query_single("SELECT 1 FROM posts WHERE user_id = #{user.id} LIMIT 1").present?

        if has_posts
          user.update!(active: false) if user.active
        else
          user.destroy!
          llm_model.update!(user: nil)
        end
      end
    end
  end
end
