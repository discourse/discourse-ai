# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class LlmPrompt
      def available_prompts
        CompletionPrompt
          .where(provider: enabled_provider)
          .where(enabled: true)
          .map do |prompt|
            translation =
              I18n.t("discourse_ai.ai_helper.prompts.#{prompt.name}", default: nil) ||
                prompt.translated_name || prompt.name

            {
              id: prompt.id,
              name: prompt.name,
              translated_name: translation,
              prompt_type: prompt.prompt_type,
            }
          end
      end

      def generate_and_send_prompt(prompt, text)
        case enabled_provider
        when "openai"
          openai_call(prompt, text)
        when "anthropic"
          anthropic_call(prompt, text)
        when "huggingface"
          huggingface_call(prompt, text)
        end
      end

      def enabled_provider
        case SiteSetting.ai_helper_model
        when /gpt/
          "openai"
        when /claude/
          "anthropic"
        else
          "huggingface"
        end
      end

      private

      def generate_diff(text, suggestion)
        cooked_text = PrettyText.cook(text)
        cooked_suggestion = PrettyText.cook(suggestion)

        DiscourseDiff.new(cooked_text, cooked_suggestion).inline_html
      end

      def parse_content(prompt, content)
        return "" if content.blank?

        case enabled_provider
        when "openai"
          return content.strip if !prompt.list?

          content.gsub("\"", "").gsub(/\d./, "").split("\n").map(&:strip)
        when "anthropic"
          parse_antropic_content(prompt, content)
        when "huggingface"
          return [content.strip.delete_prefix('"').delete_suffix('"')] if !prompt.list?

          content.gsub("\"", "").gsub(/\d./, "").split("\n").map(&:strip)
        end
      end

      def openai_call(prompt, text)
        result = { type: prompt.prompt_type }

        messages = prompt.messages_with_user_input(text)

        result[:suggestions] = DiscourseAi::Inference::OpenAiCompletions
          .perform!(messages, SiteSetting.ai_helper_model)
          .dig(:choices)
          .to_a
          .flat_map { |choice| parse_content(prompt, choice.dig(:message, :content).to_s) }
          .compact_blank

        result[:diff] = generate_diff(text, result[:suggestions].first) if prompt.diff?

        result
      end

      def anthropic_call(prompt, text)
        result = { type: prompt.prompt_type }

        filled_message = prompt.messages_with_user_input(text)

        message =
          filled_message.map { |msg| "#{msg["role"]}: #{msg["content"]}" }.join("\n\n") +
            "Assistant:"

        response = DiscourseAi::Inference::AnthropicCompletions.perform!(message)

        result[:suggestions] = parse_content(prompt, response.dig(:completion))

        result[:diff] = generate_diff(text, result[:suggestions].first) if prompt.diff?

        result
      end

      def huggingface_call(prompt, text)
        result = { type: prompt.prompt_type }

        message = prompt.messages_with_user_input(text)

        response =
          DiscourseAi::Inference::HuggingFaceTextGeneration.perform!(
            message,
            SiteSetting.ai_helper_model,
          )

        result[:suggestions] = parse_content(prompt, response.dig(:generated_text))

        result[:diff] = generate_diff(text, result[:suggestions].first) if prompt.diff?

        result
      end

      def parse_antropic_content(prompt, content)
        if prompt.list?
          suggestions = Nokogiri::HTML5.fragment(content).search("ai").map(&:text)

          if suggestions.length > 1
            suggestions
          else
            suggestions.first.split("\n").map(&:strip)
          end
        else
          [Nokogiri::HTML5.fragment(content).at("ai").text]
        end
      end
    end
  end
end
