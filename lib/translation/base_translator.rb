# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseTranslator
      def initialize(text:, target_locale:, topic: nil, post: nil)
        @text = text
        @target_locale = target_locale
        @topic = topic
        @post = post
      end

      def translate
        return nil if !SiteSetting.ai_translation_enabled
        if (ai_persona = AiPersona.find_by(id: persona_setting)).blank?
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
            messages: [{ type: :user, content: formatted_content }],
            topic: @topic,
            post: @post,
          )

        structured_output = nil
        bot.reply(context) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        structured_output&.read_buffered_property(:translation)
      end

      def formatted_content
        { content: @text, target_locale: @target_locale }.to_json
      end

      private

      def persona_setting
        raise NotImplementedError
      end

      def preferred_llm_model(persona_klass)
        persona_klass.default_llm_id || SiteSetting.ai_translation_model&.split(":")&.last
      end
    end
  end
end
