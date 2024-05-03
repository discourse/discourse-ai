# frozen_string_literal: true

class AiPersona < ActiveRecord::Base
  # places a hard limit, so per site we cache a maximum of 500 classes
  MAX_PERSONAS_PER_SITE = 500

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :system_prompt, presence: true, length: { maximum: 10_000_000 }
  validate :system_persona_unchangeable, on: :update, if: :system
  validates :max_context_posts, numericality: { greater_than: 0 }, allow_nil: true
  # leaves some room for growth but sets a maximum to avoid memory issues
  # we may want to revisit this in the future
  validates :vision_max_pixels, numericality: { greater_than: 0, maximum: 4_000_000 }

  validates :rag_chunk_tokens, numericality: { greater_than: 0, maximum: 50_000 }
  validates :rag_chunk_overlap_tokens, numericality: { greater_than: -1, maximum: 200 }
  validates :rag_conversation_chunks, numericality: { greater_than: 0, maximum: 1000 }

  belongs_to :created_by, class_name: "User"
  belongs_to :user

  has_many :upload_references, as: :target, dependent: :destroy
  has_many :uploads, through: :upload_references

  has_many :rag_document_fragment, dependent: :destroy

  has_many :rag_document_fragments, through: :ai_persona_rag_document_fragments

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

  def self.persona_class_by_id(id)
    AiPersona.all_personas.find { |persona| persona.id == id } if id
  end

  def self.persona_users(user: nil)
    persona_users =
      persona_cache[:persona_users] ||= AiPersona
        .where(enabled: true)
        .joins(:user)
        .pluck(
          "ai_personas.id, users.id, users.username_lower, allowed_group_ids, default_llm, mentionable",
        )
        .map do |id, user_id, username, allowed_group_ids, default_llm, mentionable|
          {
            id: id,
            user_id: user_id,
            username: username,
            allowed_group_ids: allowed_group_ids,
            default_llm: default_llm,
            mentionable: mentionable,
          }
        end

    if user
      persona_users.select { |mentionable| user.in_any_groups?(mentionable[:allowed_group_ids]) }
    else
      persona_users
    end
  end

  def self.topic_responder_for(category_id:)
    return nil if !category_id

    all_responders =
      persona_cache[:topic_responders] ||= AiPersona
        .where(role: "topic_responder")
        .where(enabled: true)
        .pluck(:id, :role_category_ids)

    id, _ = all_responders.find { |id, role_category_ids| role_category_ids.include?(category_id) }

    if id
      { id: id }
    else
      nil
    end
  end

  def self.message_responder_for(group_id: nil)
    return nil if !group_id

    all_responders =
      persona_cache[:message_responders] ||= AiPersona
        .where(role: "message_responder")
        .where(enabled: true)
        .pluck(:id, :role_group_ids)

    id, _ = all_responders.find { |id, role_group_ids| role_group_ids.include?(group_id) }

    if id
      { id: id }
    else
      nil
    end
  end

  def self.mentionables(user: nil)
    all_mentionables =
      persona_cache[:mentionable_usernames] ||= AiPersona
        .where(mentionable: true)
        .where(enabled: true)
        .joins(:user)
        .pluck("ai_personas.id, users.id, users.username_lower, allowed_group_ids, default_llm")
        .map do |id, user_id, username, allowed_group_ids, default_llm|
          {
            id: id,
            user_id: user_id,
            username: username,
            allowed_group_ids: allowed_group_ids,
            default_llm: default_llm,
          }
        end

    if user
      all_mentionables.select { |mentionable| user.in_any_groups?(mentionable[:allowed_group_ids]) }
    else
      all_mentionables
    end
  end

  after_commit :bump_cache

  def bump_cache
    self.class.persona_cache.flush!
  end

  def class_instance
    allowed_group_ids = self.allowed_group_ids
    id = self.id
    system = self.system
    user_id = self.user_id
    mentionable = self.mentionable
    default_llm = self.default_llm
    max_context_posts = self.max_context_posts
    vision_enabled = self.vision_enabled
    vision_max_pixels = self.vision_max_pixels
    rag_conversation_chunks = self.rag_conversation_chunks
    question_consolidator_llm = self.question_consolidator_llm
    role = self.role
    role_whispers = self.role_whispers

    persona_class = DiscourseAi::AiBot::Personas::Persona.system_personas_by_id[self.id]
    if persona_class
      persona_class.define_singleton_method :allowed_group_ids do
        allowed_group_ids
      end

      persona_class.define_singleton_method :id do
        id
      end

      persona_class.define_singleton_method :system do
        system
      end

      persona_class.define_singleton_method :user_id do
        user_id
      end

      persona_class.define_singleton_method :mentionable do
        mentionable
      end

      persona_class.define_singleton_method :default_llm do
        default_llm
      end

      persona_class.define_singleton_method :max_context_posts do
        max_context_posts
      end

      persona_class.define_singleton_method :vision_enabled do
        vision_enabled
      end

      persona_class.define_singleton_method :vision_max_pixels do
        vision_max_pixels
      end

      persona_class.define_singleton_method :question_consolidator_llm do
        question_consolidator_llm
      end

      persona_class.define_singleton_method :rag_conversation_chunks do
        rag_conversation_chunks
      end

      persona_class.define_singleton_method :role_whispers do
        role_whispers
      end

      persona_class.define_singleton_method :role do
        role
      end

      return persona_class
    end

    name = self.name
    description = self.description
    ai_persona_id = self.id

    options = {}

    tools = self.respond_to?(:commands) ? self.commands : self.tools

    tools =
      tools.filter_map do |element|
        inner_name = element
        current_options = nil

        if element.is_a?(Array)
          inner_name = element[0]
          current_options = element[1]
        end

        # Won't migrate data yet. Let's rewrite to the tool name.
        inner_name = inner_name.gsub("Command", "")
        inner_name = "List#{inner_name}" if %w[Categories Tags].include?(inner_name)

        begin
          klass = ("DiscourseAi::AiBot::Tools::#{inner_name}").constantize
          options[klass] = current_options if current_options
          klass
        rescue StandardError
          nil
        end
      end

    Class.new(DiscourseAi::AiBot::Personas::Persona) do
      define_singleton_method :id do
        id
      end

      define_singleton_method :name do
        name
      end

      define_singleton_method :user_id do
        user_id
      end

      define_singleton_method :description do
        description
      end

      define_singleton_method :system do
        system
      end

      define_singleton_method :allowed_group_ids do
        allowed_group_ids
      end

      define_singleton_method :user_id do
        user_id
      end

      define_singleton_method :mentionable do
        mentionable
      end

      define_singleton_method :default_llm do
        default_llm
      end

      define_singleton_method :max_context_posts do
        max_context_posts
      end

      define_singleton_method :vision_enabled do
        vision_enabled
      end

      define_singleton_method :vision_max_pixels do
        vision_max_pixels
      end

      define_singleton_method :rag_conversation_chunks do
        rag_conversation_chunks
      end

      define_singleton_method :question_consolidator_llm do
        question_consolidator_llm
      end

      define_singleton_method :role do
        role
      end

      define_singleton_method :role_whispers do
        role_whispers
      end

      define_singleton_method :to_s do
        "#<DiscourseAi::AiBot::Personas::Persona::Custom @name=#{self.name} @allowed_group_ids=#{self.allowed_group_ids.join(",")}>"
      end

      define_singleton_method :inspect do
        "#<DiscourseAi::AiBot::Personas::Persona::Custom @name=#{self.name} @allowed_group_ids=#{self.allowed_group_ids.join(",")}>"
      end

      define_method :initialize do |*args, **kwargs|
        @ai_persona = AiPersona.find_by(id: ai_persona_id)
        super(*args, **kwargs)
      end

      define_method :persona_id do
        @ai_persona&.id
      end

      define_method :tools do
        tools
      end

      define_method :options do
        options
      end

      define_method :temperature do
        @ai_persona&.temperature
      end

      define_method :top_p do
        @ai_persona&.top_p
      end

      define_method :system_prompt do
        @ai_persona&.system_prompt || "You are a helpful bot."
      end

      define_method :uploads do
        @ai_persona&.uploads
      end
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
      RagDocumentFragment.where(ai_persona: self).delete_all
    end
  end

  private

  def system_persona_unchangeable
    if role_changed? || top_p_changed? || temperature_changed? || system_prompt_changed? ||
         commands_changed? || name_changed? || description_changed?
      errors.add(:base, I18n.t("discourse_ai.ai_bot.personas.cannot_edit_system_persona"))
    end
  end

  def ensure_not_system
    if system
      errors.add(:base, I18n.t("discourse_ai.ai_bot.personas.cannot_delete_system_persona"))
      throw :abort
    end
  end
end

# == Schema Information
#
# Table name: ai_personas
#
#  id                          :bigint           not null, primary key
#  name                        :string(100)      not null
#  description                 :string(2000)     not null
#  commands                    :json             not null
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
#  mentionable                 :boolean          default(FALSE), not null
#  default_llm                 :text
#  max_context_posts           :integer
#  max_post_context_tokens     :integer
#  max_context_tokens          :integer
#  vision_enabled              :boolean          default(FALSE), not null
#  vision_max_pixels           :integer          default(1048576), not null
#  rag_chunk_tokens            :integer          default(374), not null
#  rag_chunk_overlap_tokens    :integer          default(10), not null
#  rag_conversation_chunks     :integer          default(10), not null
#  question_consolidator_llm   :text
#  role                        :enum             default("bot"), not null
#  role_category_ids           :integer          default([]), not null, is an Array
#  role_tags                   :string           default([]), not null, is an Array
#  role_group_ids              :integer          default([]), not null, is an Array
#  role_whispers               :boolean          default(FALSE), not null
#  role_max_responses_per_hour :integer          default(50), not null
#
# Indexes
#
#  index_ai_personas_on_name  (name) UNIQUE
#
