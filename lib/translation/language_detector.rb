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

        llm_model = preferred_llm_model(ai_persona, persona_klass)
        return nil if llm_model.blank?

        prompt =
          DiscourseAi::Completions::Prompt.new(
            ai_persona.system_prompt,
            messages: [{ type: :user, content: @text, id: "user" }],
          )
        response_format = persona_klass.new.response_format
        structured_output =
          DiscourseAi::Completions::Llm.proxy(llm_model).generate(
            prompt,
            user: ai_persona.user || Discourse.system_user,
            feature_name: "translation",
            response_format:,
          )

        structured_output&.read_buffered_property(:locale)
      end

      def response_format
        {
          type: "json_schema",
          json_schema: {
            name: "reply",
            schema: {
              type: "object",
              properties: {
                locale: {
                  type: "string",
                },
              },
              required: ["locale"],
              additionalProperties: false,
            },
            strict: true,
          },
        }
      end

      private

      def preferred_llm_model(ai_persona, persona_klass)
        if ai_persona.force_default_llm
          persona_klass.default_llm_id
        else
          SiteSetting.ai_translation_model.presence || persona_klass.default_llm_id
        end
      end
    end
  end
end
