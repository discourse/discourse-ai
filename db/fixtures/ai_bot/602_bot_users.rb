# frozen_string_literal: true

UserEmail.seed do |ue|
  ue.id = -110
  ue.email = "no_email_gpt_bot"
  ue.primary = true
  ue.user_id = -110
end

User.seed do |u|
  u.id = -110
  u.name = "GPT Bot"
  u.username = UserNameSuggester.suggest("gpt_bot")
  u.password = SecureRandom.hex
  u.active = true
  u.admin = true
  u.moderator = true
  u.approved = true
  u.trust_level = TrustLevel[4]
end
