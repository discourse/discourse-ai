# frozen_string_literal: true

DiscourseAi::AiBot::Personas.system_personas.each do |persona_class, id|
  persona = AiPersona.find_by(id: id)
  if !persona
    persona = AiPersona.new
    persona.id = id
    persona.allowed_group_ids = [Group::AUTO_GROUPS[:trust_level_0]]
    persona.enabled = true
    persona.priority = true if persona_class == DiscourseAi::AiBot::Personas::General
  end

  names = [
    persona_class.name,
    persona_class.name + " 1",
    persona_class.name + " 2",
    persona_class.name + SecureRandom.hex,
  ]
  persona.name = DB.query_single(<<~SQL, names, id).first
        SELECT guess_name
        FROM (
          SELECT unnest(Array[?]) AS guess_name
          FROM (SELECT 1) as t
        ) x
        LEFT JOIN ai_personas ON ai_personas.name = x.guess_name AND ai_personas.id <> ?
        WHERE ai_personas.id IS NULL
        ORDER BY x.guess_name ASC
        LIMIT 1
      SQL

  persona.description = persona_class.description

  persona.system = true
  instance = persona_class.new
  persona.commands = instance.commands.map { |command| command.to_s.split("::").last }
  persona.system_prompt = instance.system_prompt
  persona.save!(validate: false)
end
