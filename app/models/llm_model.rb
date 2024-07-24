# frozen_string_literal: true

class LlmModel < ActiveRecord::Base
  FIRST_BOT_USER_ID = -1200
  RESERVED_VLLM_SRV_URL = "https://vllm.shadowed-by-srv.invalid"
  BEDROCK_PROVIDER_NAME = "aws_bedrock"

  belongs_to :user

  validates :url, exclusion: { in: [RESERVED_VLLM_SRV_URL] }, if: :url_changed?

  def self.seed_srv_backed_model
    srv = SiteSetting.ai_vllm_endpoint_srv
    srv_model = find_by(url: RESERVED_VLLM_SRV_URL)

    if srv.present?
      if srv_model.present?
        current_key = SiteSetting.ai_vllm_api_key
        srv_model.update!(api_key: current_key) if current_key != srv_model.api_key
      else
        record =
          new(
            display_name: "vLLM SRV LLM",
            name: "mistralai/Mixtral-8x7B-Instruct-v0.1",
            provider: "vllm",
            tokenizer: "DiscourseAi::Tokenizer::MixtralTokenizer",
            url: RESERVED_VLLM_SRV_URL,
            max_prompt_tokens: 8000,
            api_key: SiteSetting.ai_vllm_api_key,
          )

        record.save(validate: false) # Ignore reserved URL validation
      end
    else
      # Clean up companion users
      srv_model&.enabled_chat_bot = false
      srv_model&.toggle_companion_user

      srv_model&.destroy!
    end
  end

  def self.provider_params
    {
      aws_bedrock: {
        url_editable: false,
        fields: %i[access_key_id region],
      },
      open_ai: {
        url_editable: true,
        fields: %i[organization],
      },
    }
  end

  def to_llm
    DiscourseAi::Completions::Llm.proxy_from_obj(self)
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
