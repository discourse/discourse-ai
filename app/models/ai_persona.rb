# frozen_string_literal: true

class AiPersona < ActiveRecord::Base
  class MultisiteHash
    def initialize(id)
      @hash = Hash.new({})
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

  def self.all_personas
    persona_cache[:value] ||= AiPersona.all.map do |ai_persona|
      name = ai_persona.name
      description = ai_persona.description
      system_prompt = ai_persona.system_prompt
      allowed_group_ids = ai_persona.allowed_group_ids
      commands =
        ai_persona.commands.filter_map do |inner_name|
          begin
            ("DiscourseAi::AiBot::Commands::#{inner_name}").constantize
          rescue StandardError
            nil
          end
        end

      Class.new(DiscourseAi::AiBot::Personas::Persona) do
        define_singleton_method :name do
          name
        end

        define_singleton_method :description do
          description
        end

        define_singleton_method :allowed_group_ids do
          allowed_group_ids
        end

        define_method :commands do
          commands
        end

        define_method :system_prompt do
          system_prompt
        end
      end
    end
  end

  after_commit :bump_cache

  def bump_cache
    self.class.persona_cache.flush!
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
#  system_prompt     :string           not null
#  allowed_group_ids :integer          default([]), not null, is an Array
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_ai_personas_on_name  (name) UNIQUE
#
