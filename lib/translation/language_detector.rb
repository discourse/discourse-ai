# frozen_string_literal: true

module DiscourseAi
  module Translation
    class LanguageDetector
      DETECTION_CHAR_LIMIT = 1000

      def initialize(text)
        @text = text
      end

      def detect
        return nil if !SiteSetting.ai_translation_enabled
        if (
             ai_persona = AiPersona.find_by(id: SiteSetting.ai_translation_locale_detection_persona)
           ).blank?
          return nil
        end

        persona_klass = ai_persona.class_instance
        persona = persona_klass.new

        llm_model = LlmModel.find_by(id: preferred_llm_model(persona_klass))
        return nil if llm_model.blank?

        bot =
          DiscourseAi::Personas::Bot.as(
            ai_persona.user || Discourse.system_user,
            persona: persona,
            model: llm_model,
          )

        context =
          DiscourseAi::Personas::BotContext.new(
            user: ai_persona.user || Discourse.system_user,
            skip_tool_details: true,
            feature_name: "translation",
            messages: [{ type: :user, content: @text }],
          )

        structured_output = nil
        bot.reply(context) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end
        structured_output&.read_buffered_property(:locale) || []
      end

      private

      def preferred_llm_model(persona_klass)
        persona_klass.default_llm_id || SiteSetting.ai_translation_model&.split(":")&.last
      end
    end
  end
end
