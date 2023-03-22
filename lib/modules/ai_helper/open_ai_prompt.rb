# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class OpenAiPrompt
      def available_prompts
        CompletionPrompt
          .where(enabled: true)
          .map do |prompt|
            translation =
              I18n.t("discourse_ai.ai_helper.prompts.#{prompt.name}", default: nil) ||
                prompt.translated_name

            { name: prompt.name, translated_name: translation, prompt_type: prompt.prompt_type }
          end
      end

      def generate_and_send_prompt(prompt, text)
        result = { type: prompt.prompt_type }

        messages = prompt.messages_with_user_input(text)

        result[:suggestions] = DiscourseAi::Inference::OpenAiCompletions
          .perform!(messages)
          .dig(:choices)
          .to_a
          .flat_map { |choice| parse_content(prompt, choice.dig(:message, :content).to_s) }
          .compact_blank

        result[:diff] = generate_diff(text, result[:suggestions].first) if prompt.diff?

        result
      end

      private

      def generate_diff(text, suggestion)
        cooked_text = PrettyText.cook(text)
        cooked_suggestion = PrettyText.cook(suggestion)

        DiscourseDiff.new(cooked_text, cooked_suggestion).inline_html
      end

      def parse_content(prompt, content)
        return "" if content.blank?
        return content.strip if !prompt.list?

        content.gsub("\"", "").gsub(/\d./, "").split("\n").map(&:strip)
      end
    end
  end
end
