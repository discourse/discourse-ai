# frozen_string_literal: true

class AiPersona < ActiveRecord::Base
  # places a hard limit, so per site we cache a maximum of 500 classes
  MAX_PERSONAS_PER_SITE = 500

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :system_prompt, presence: true
  validate :system_persona_unchangeable, on: :update, if: :system

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
      .map(&:instance)
  end

  after_commit :bump_cache

  def bump_cache
    self.class.persona_cache.flush!
  end

  def instance
    allowed_group_ids = self.allowed_group_ids
    id = self.id
    system = self.system

    persona_class = DiscourseAi::AiBot::Personas.system_personas_by_id[self.id]
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
    commands =
      self.commands.filter_map do |inner_name|
        begin
          ("DiscourseAi::AiBot::Commands::#{inner_name}").constantize
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

      define_method :commands do
        commands
      end

      define_method :system_prompt do
        @ai_persona&.system_prompt || "You are a helpful bot."
      end
    end
  end

  private

  def system_persona_unchangeable
    if system_prompt_changed? || commands_changed? || name_changed? || description_changed?
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
#  commands          :string           default([]), not null, is an Array
#  system_prompt     :string(10000000) not null
#  allowed_group_ids :integer          default([]), not null, is an Array
#  created_by_id     :integer
#  enabled           :boolean          default(TRUE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  system            :boolean          default(FALSE), not null
#  priority          :integer          default(0), not null
#
# Indexes
#
#  index_ai_personas_on_name  (name) UNIQUE
#
