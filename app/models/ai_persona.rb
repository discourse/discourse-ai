# frozen_string_literal: true

class AiPersona < ActiveRecord::Base
  # places a hard limit, so per site we cache a maximum of 500 classes
  MAX_PERSONAS_PER_SITE = 500

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :system_prompt, presence: true, length: { maximum: 10_000_000 }
  validate :system_persona_unchangeable, on: :update, if: :system

  belongs_to :created_by, class_name: "User"
  belongs_to :user

  before_destroy :ensure_not_system

  class MultisiteHash
    def initialize(id)
      @hash = Hash.new { |h, k| h[k] = {} }
      @id = id

      MessageBus.subscribe(channel_name) { |message| @hash[message.data] = {} }
    end

    def channel_name
      "/multisite-hash-#{@id}"
    end

    def current_db
      RailsMultisite::ConnectionManagement.current_db
    end

    def [](key)
      @hash.dig(current_db, key)
    end

    def []=(key, val)
      @hash[current_db][key] = val
    end

    def flush!
      @hash[current_db] = {}
      MessageBus.publish(channel_name, current_db)
    end
  end

  def self.persona_cache
    @persona_cache ||= MultisiteHash.new("persona_cache")
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

  def self.mentionables
    persona_cache[:mentionable_usernames] ||= AiPersona
      .where(mentionable: true)
      .where(enabled: true)
      .joins(:user)
      .pluck("ai_personas.id, users.id, lower(users.username), allowed_group_ids, default_llm")
      .map do |id, user_id, username, allowed_group_ids, default_llm|
        {
          id: id,
          user_id: user_id,
          username: username,
          allowed_group_ids: allowed_group_ids,
          default_llm: default_llm,
        }
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
    end
  end

  def create_user!
    raise "User already exists" if user_id && User.exists?(user_id)

    # note .invalid is a reserved TLD which will route nowhere
    user =
      User.new(
        email: "no_email_#{name}@does-not-exist.invalid",
        name: name.titleize,
        username: UserNameSuggester.suggest(name + "_bot"),
        active: true,
        approved: true,
        trust_level: TrustLevel[4],
      )
    user.save!(validate: false)

    update!(user_id: user.id)
    user
  end

  private

  def system_persona_unchangeable
    if top_p_changed? || temperature_changed? || system_prompt_changed? || commands_changed? ||
         name_changed? || description_changed?
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
#  id                :bigint           not null, primary key
#  name              :string(100)      not null
#  description       :string(2000)     not null
#  commands          :json             not null
#  system_prompt     :string(10000000) not null
#  allowed_group_ids :integer          default([]), not null, is an Array
#  created_by_id     :integer
#  enabled           :boolean          default(TRUE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  system            :boolean          default(FALSE), not null
#  priority          :boolean          default(FALSE), not null
#  temperature       :float
#  top_p             :float
#  user_id           :integer
#  mentionable       :boolean          default(FALSE), not null
#  default_llm       :text
#
# Indexes
#
#  index_ai_personas_on_name  (name) UNIQUE
#
