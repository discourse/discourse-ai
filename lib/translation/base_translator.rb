# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseTranslator
      def initialize(text:, target_locale:, topic_id: nil, post_id: nil)
        @text = text
        @target_locale = target_locale
        @topic_id = topic_id
        @post_id = post_id
      end

      def translate
        prompt =
          DiscourseAi::Completions::Prompt.new(
            prompt_template,
            messages: [{ type: :user, content: formatted_content, id: "user" }],
            topic_id: @topic_id,
            post_id: @post_id,
          )

        structured_output =
          DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_translation_model).generate(
            prompt,
            user: Discourse.system_user,
            feature_name: "translation",
            response_format: response_format,
          )

        structured_output&.read_buffered_property(:translation)
      end

      def formatted_content
        { content: @text, target_locale: @target_locale }.to_json
      end

      def response_format
        {
          type: "json_schema",
          json_schema: {
            name: "reply",
            schema: {
              type: "object",
              properties: {
                translation: {
                  type: "string",
                },
              },
              required: ["translation"],
              additionalProperties: false,
            },
            strict: true,
          },
        }
      end

      private

      def prompt_template
        raise NotImplementedError
      end
    end
  end
end
