# frozen_string_literal: true

class LlmModel < ActiveRecord::Base
  FIRST_BOT_USER_ID = -1200
  BEDROCK_PROVIDER_NAME = "aws_bedrock"

  belongs_to :user

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :tokenizer, presence: true, inclusion: DiscourseAi::Completions::Llm.tokenizer_names
  validates :provider, presence: true, inclusion: DiscourseAi::Completions::Llm.provider_names
  validates :url, presence: true, unless: -> { provider == BEDROCK_PROVIDER_NAME }
  validates_presence_of :name, :api_key
  validates :max_prompt_tokens, numericality: { greater_than: 0 }
  validate :required_provider_params

  def self.provider_params
    {
      aws_bedrock: {
        access_key_id: :text,
        region: :text,
        disable_native_tools: :checkbox,
      },
      anthropic: {
        disable_native_tools: :checkbox,
      },
      open_ai: {
        organization: :text,
      },
      google: {
        disable_native_tools: :checkbox,
      },
      hugging_face: {
        disable_system_prompt: :checkbox,
      },
      vllm: {
        disable_system_prompt: :checkbox,
      },
      ollama: {
        disable_system_prompt: :checkbox,
        enable_native_tool: :checkbox,
      },
    }
  end

  def to_llm
    DiscourseAi::Completions::Llm.proxy("custom:#{id}")
  end

  def toggle_companion_user
    return if name == "fake" && Rails.env.production?

    enable_check = SiteSetting.ai_bot_enabled && enabled_chat_bot

    if enable_check
      if !user
        next_id = DB.query_single(<<~SQL).first
          SELECT min(id) - 1 FROM users
        SQL

        new_user =
          User.new(
            id: [FIRST_BOT_USER_ID, next_id].min,
            email: "no_email_#{SecureRandom.hex}",
            name: name.titleize,
            username: UserNameSuggester.suggest(name),
            active: true,
            approved: true,
            admin: true,
            moderator: true,
            trust_level: TrustLevel[4],
          )
        new_user.save!(validate: false)
        self.update!(user: new_user)
      else
        user.active = true
        user.save!(validate: false)
      end
    elsif user
      # will include deleted
      has_posts = DB.query_single("SELECT 1 FROM posts WHERE user_id = #{user.id} LIMIT 1").present?

      if has_posts
        user.update!(active: false) if user.active
      else
        user.destroy!
        self.update!(user: nil)
      end
    end
  end

  def tokenizer_class
    tokenizer.constantize
  end

  def lookup_custom_param(key)
    provider_params&.dig(key)
  end

  def seeded?
    id.present? && id < 0
  end

  def api_key
    if seeded?
      env_key = "DISCOURSE_AI_SEEDED_LLM_API_KEY_#{id.abs}"
      ENV[env_key] || self[:api_key]
    else
      self[:api_key]
    end
  end

  private

  def required_provider_params
    return if provider != BEDROCK_PROVIDER_NAME

    %w[access_key_id region].each do |field|
      if lookup_custom_param(field).blank?
        errors.add(:base, I18n.t("discourse_ai.llm_models.missing_provider_param", param: field))
      end
    end
  end
end

# == Schema Information
#
# Table name: llm_models
#
#  id                :bigint           not null, primary key
#  display_name      :string
#  name              :string           not null
#  provider          :string           not null
#  tokenizer         :string           not null
#  max_prompt_tokens :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  url               :string
#  api_key           :string
#  user_id           :integer
#  enabled_chat_bot  :boolean          default(FALSE), not null
#  provider_params   :jsonb
#  vision_enabled    :boolean          default(FALSE), not null
#
