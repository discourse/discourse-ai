# frozen_string_literal: true

module DiscourseAi::AiBot::SiteSettingsExtension
  FIRST_BOT_USER_ID = -1200

  def self.enable_or_disable_ai_bots
    enabled_bots = SiteSetting.ai_bot_enabled_chat_bots_map
    enabled_bots = [] if !SiteSetting.ai_bot_enabled

    all_bots = base_bots.concat(custom_bots)
    all_bots += LlmModel.pluck(:display_name, :name)

    base_bots.each do |bot_name, llm|
      next if llm == "fake" && Rails.env.production?

      active = enabled_bots.include?(llm)
      user =
        User.joins(:_custom_fields).find_by(
          user_custom_fields: {
            name: DiscourseAi::AiBot::EntryPoint::BOT_MODEL_CUSTOM_FIELD,
            value: llm,
          },
        )

      if active
        if !user
          id = DB.query_single(<<~SQL).first
            SELECT min(id) - 1 FROM users
          SQL

          user =
            User.new(
              id: [FIRST_BOT_USER_ID, id].min,
              email: "no_email_#{llm}",
              name: bot_name.titleize,
              username: UserNameSuggester.suggest(bot_name),
              active: true,
              approved: true,
              admin: true,
              moderator: true,
              trust_level: TrustLevel[4],
            )
          user.save!(validate: false)
          user.upsert_custom_fields(DiscourseAi::AiBot::EntryPoint::BOT_MODEL_CUSTOM_FIELD => llm)
        else
          user.update_columns(active: true)
        end
      elsif !active && user
        # will include deleted
        has_posts =
          DB.query_single("SELECT 1 FROM posts WHERE user_id = #{user.id} LIMIT 1").present?

        if has_posts
          user.update_columns(active: false) if user.active
        else
          user.destroy
        end
      end
    end
  end

  def self.base_bots
    [
      %w[gpt4_bot gpt-4],
      %w[gpt3.5_bot gpt-3.5-turbo],
      %w[claude_bot claude-2],
      %w[gpt4t_bot gpt-4-turbo],
      %w[mixtral_bot mixtral-8x7B-Instruct-V0.1],
      %w[gemini_bot gemini-1.5-pro],
      %w[fake_bot fake],
      %w[claude_3_opus_bot claude-3-opus],
      %w[claude_3_sonnet_bot claude-3-sonnet],
      %w[claude_3_haiku_bot claude-3-haiku],
      %w[cohere_command_bot cohere-command-r-plus],
      %w[gpt4o_bot gpt-4o],
    ]
  end
end
