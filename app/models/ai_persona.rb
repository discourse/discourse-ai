# frozen_string_literal: true

class AiPersona < ActiveRecord::Base
  # TODO remove this line 01-1-2025
  self.ignored_columns = %i[commands allow_chat mentionable]

  # places a hard limit, so per site we cache a maximum of 500 classes
  MAX_PERSONAS_PER_SITE = 500

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :system_prompt, presence: true, length: { maximum: 10_000_000 }
  validate :system_persona_unchangeable, on: :update, if: :system
  validate :chat_preconditions
  validate :allowed_seeded_model, if: :default_llm
  validates :max_context_posts, numericality: { greater_than: 0 }, allow_nil: true
  # leaves some room for growth but sets a maximum to avoid memory issues
  # we may want to revisit this in the future
  validates :vision_max_pixels, numericality: { greater_than: 0, maximum: 4_000_000 }

  validates :rag_chunk_tokens, numericality: { greater_than: 0, maximum: 50_000 }
  validates :rag_chunk_overlap_tokens, numericality: { greater_than: -1, maximum: 200 }
  validates :rag_conversation_chunks, numericality: { greater_than: 0, maximum: 1000 }
  validates :forced_tool_count, numericality: { greater_than: -2, maximum: 100_000 }
  has_many :rag_document_fragments, dependent: :destroy, as: :target

  belongs_to :created_by, class_name: "User"
  belongs_to :user

  has_many :upload_references, as: :target, dependent: :destroy
  has_many :uploads, through: :upload_references

  before_destroy :ensure_not_system
  before_update :regenerate_rag_fragments

  def self.persona_cache
    @persona_cache ||= ::DiscourseAi::MultisiteHash.new("persona_cache")
  end

  scope :ordered, -> { order("priority DESC, lower(name) ASC") }

  def self.all_personas
    persona_cache[:value] ||= AiPersona
      .ordered
      .where(enabled: true)
      .all
      .limit(MAX_PERSONAS_PER_SITE)
      .map(&:class_instance)
  end

  def self.persona_users(user: nil)
    persona_users =
      persona_cache[:persona_users] ||= AiPersona
        .where(enabled: true)
        .joins(:user)
        .map do |persona|
          {
            id: persona.id,
            user_id: persona.user_id,
            username: persona.user.username_lower,
            allowed_group_ids: persona.allowed_group_ids,
            default_llm: persona.default_llm,
            force_default_llm: persona.force_default_llm,
            allow_chat_channel_mentions: persona.allow_chat_channel_mentions,
            allow_chat_direct_messages: persona.allow_chat_direct_messages,
            allow_topic_mentions: persona.allow_topic_mentions,
            allow_personal_messages: persona.allow_personal_messages,
          }
        end

    if user
      persona_users.select { |persona_user| user.in_any_groups?(persona_user[:allowed_group_ids]) }
    else
      persona_users
    end
  end

  def self.allowed_modalities(
    user: nil,
    allow_chat_channel_mentions: false,
    allow_chat_direct_messages: false,
    allow_topic_mentions: false,
    allow_personal_messages: false
  )
    index =
      "modality-#{allow_chat_channel_mentions}-#{allow_chat_direct_messages}-#{allow_topic_mentions}-#{allow_personal_messages}"

    personas =
      persona_cache[index.to_sym] ||= persona_users.select do |persona|
        next true if allow_chat_channel_mentions && persona[:allow_chat_channel_mentions]
        next true if allow_chat_direct_messages && persona[:allow_chat_direct_messages]
        next true if allow_topic_mentions && persona[:allow_topic_mentions]
        next true if allow_personal_messages && persona[:allow_personal_messages]
        false
      end

    if user
      personas.select { |u| user.in_any_groups?(u[:allowed_group_ids]) }
    else
      personas
    end
  end

  after_commit :bump_cache

  def bump_cache
    self.class.persona_cache.flush!
  end

  def class_instance
    attributes = %i[
      id
      user_id
      system
      mentionable
      default_llm
      max_context_posts
      vision_enabled
      vision_max_pixels
      rag_conversation_chunks
      question_consolidator_llm
      allow_chat_channel_mentions
      allow_chat_direct_messages
      allow_topic_mentions
      allow_personal_messages
      force_default_llm
      name
      description
      allowed_group_ids
      tool_details
    ]

    persona_class = DiscourseAi::AiBot::Personas::Persona.system_personas_by_id[self.id]

    instance_attributes = {}
    attributes.each do |attr|
      value = self.read_attribute(attr)
      instance_attributes[attr] = value
    end

    instance_attributes[:username] = user&.username_lower

    if persona_class
      instance_attributes.each do |key, value|
        # description/name are localized
        persona_class.define_singleton_method(key) { value } if key != :description && key != :name
      end
      return persona_class
    end

    options = {}
    force_tool_use = []

    tools =
      self.tools.filter_map do |element|
        klass = nil

        element = [element] if element.is_a?(String)

        inner_name, current_options, should_force_tool_use =
          element.is_a?(Array) ? element : [element, nil]

        if inner_name.start_with?("custom-")
          custom_tool_id = inner_name.split("-", 2).last.to_i
          if AiTool.exists?(id: custom_tool_id, enabled: true)
            klass = DiscourseAi::AiBot::Tools::Custom.class_instance(custom_tool_id)
          end
        else
          inner_name = inner_name.gsub("Tool", "")
          inner_name = "List#{inner_name}" if %w[Categories Tags].include?(inner_name)

          begin
            klass = "DiscourseAi::AiBot::Tools::#{inner_name}".constantize
            options[klass] = current_options if current_options
          rescue StandardError
          end
        end

        force_tool_use << klass if should_force_tool_use
        klass
      end

    ai_persona_id = self.id

    Class.new(DiscourseAi::AiBot::Personas::Persona) do
      instance_attributes.each { |key, value| define_singleton_method(key) { value } }

      define_singleton_method(:to_s) do
        "#<#{self.class.name} @name=#{name} @allowed_group_ids=#{allowed_group_ids.join(",")}>"
      end

      define_singleton_method(:inspect) { to_s }

      define_method(:initialize) do |*args, **kwargs|
        @ai_persona = AiPersona.find_by(id: ai_persona_id)
        super(*args, **kwargs)
      end

      define_method(:tools) { tools }
      define_method(:force_tool_use) { force_tool_use }
      define_method(:forced_tool_count) { @ai_persona&.forced_tool_count }
      define_method(:options) { options }
      define_method(:temperature) { @ai_persona&.temperature }
      define_method(:top_p) { @ai_persona&.top_p }
      define_method(:system_prompt) { @ai_persona&.system_prompt || "You are a helpful bot." }
      define_method(:uploads) { @ai_persona&.uploads }
    end
  end

  FIRST_PERSONA_USER_ID = -1200

  def create_user!
    raise "User already exists" if user_id && User.exists?(user_id)

    # find the first id smaller than FIRST_USER_ID that is not taken
    id = nil

    id = DB.query_single(<<~SQL, FIRST_PERSONA_USER_ID, FIRST_PERSONA_USER_ID - 200).first
        WITH seq AS (
          SELECT generate_series(?, ?, -1) AS id
          )
        SELECT seq.id FROM seq
        LEFT JOIN users ON users.id = seq.id
        WHERE users.id IS NULL
        ORDER BY seq.id DESC
      SQL

    id = DB.query_single(<<~SQL).first if id.nil?
        SELECT min(id) - 1 FROM users
      SQL

    # note .invalid is a reserved TLD which will route nowhere
    user =
      User.new(
        email: "#{SecureRandom.hex}@does-not-exist.invalid",
        name: name.titleize,
        username: UserNameSuggester.suggest(name + "_bot"),
        active: true,
        approved: true,
        trust_level: TrustLevel[4],
        id: id,
      )
    user.save!(validate: false)

    update!(user_id: user.id)
    user
  end

  def regenerate_rag_fragments
    if rag_chunk_tokens_changed? || rag_chunk_overlap_tokens_changed?
      RagDocumentFragment.where(target: self).delete_all
    end
  end

  private

  def chat_preconditions
    if (
         allow_chat_channel_mentions || allow_chat_direct_messages || allow_topic_mentions ||
           force_default_llm
       ) && !default_llm
      errors.add(:default_llm, I18n.t("discourse_ai.ai_bot.personas.default_llm_required"))
    end
  end

  def system_persona_unchangeable
    if top_p_changed? || temperature_changed? || system_prompt_changed? || name_changed? ||
         description_changed?
      errors.add(:base, I18n.t("discourse_ai.ai_bot.personas.cannot_edit_system_persona"))
    elsif tools_changed?
      old_tools = tools_change[0]
      new_tools = tools_change[1]

      old_tool_names = old_tools.map { |t| t.is_a?(Array) ? t[0] : t }.to_set
      new_tool_names = new_tools.map { |t| t.is_a?(Array) ? t[0] : t }.to_set

      if old_tool_names != new_tool_names
        errors.add(:base, I18n.t("discourse_ai.ai_bot.personas.cannot_edit_system_persona"))
      end
    end
  end

  def ensure_not_system
    if system
      errors.add(:base, I18n.t("discourse_ai.ai_bot.personas.cannot_delete_system_persona"))
      throw :abort
    end
  end

  def allowed_seeded_model
    return if default_llm.blank?

    llm = LlmModel.find_by(id: default_llm.split(":").last.to_i)
    return if llm.nil?
    return if !llm.seeded?

    return if SiteSetting.ai_bot_allowed_seeded_models.include?(llm.id.to_s)

    errors.add(:default_llm, I18n.t("discourse_ai.llm.configuration.invalid_seeded_model"))
  end
end

# == Schema Information
#
# Table name: ai_personas
#
#  id                          :bigint           not null, primary key
#  name                        :string(100)      not null
#  description                 :string(2000)     not null
#  system_prompt               :string(10000000) not null
#  allowed_group_ids           :integer          default([]), not null, is an Array
#  created_by_id               :integer
#  enabled                     :boolean          default(TRUE), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  system                      :boolean          default(FALSE), not null
#  priority                    :boolean          default(FALSE), not null
#  temperature                 :float
#  top_p                       :float
#  user_id                     :integer
#  default_llm                 :text
#  max_context_posts           :integer
#  vision_enabled              :boolean          default(FALSE), not null
#  vision_max_pixels           :integer          default(1048576), not null
#  rag_chunk_tokens            :integer          default(374), not null
#  rag_chunk_overlap_tokens    :integer          default(10), not null
#  rag_conversation_chunks     :integer          default(10), not null
#  question_consolidator_llm   :text
#  tool_details                :boolean          default(TRUE), not null
#  tools                       :json             not null
#  forced_tool_count           :integer          default(-1), not null
#  allow_chat_channel_mentions :boolean          default(FALSE), not null
#  allow_chat_direct_messages  :boolean          default(FALSE), not null
#  allow_topic_mentions        :boolean          default(FALSE), not null
#  allow_personal_messages     :boolean          default(TRUE), not null
#  force_default_llm           :boolean          default(FALSE), not null
#
# Indexes
#
#  index_ai_personas_on_name  (name) UNIQUE
#
