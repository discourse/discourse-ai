# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class Assistant
      def available_prompts(name_filter: nil)
        cp = CompletionPrompt

        prompts = name_filter ? [cp.enabled_by_name(name_filter)] : cp.where(enabled: true)

        prompts.map do |prompt|
          translation =
            I18n.t("discourse_ai.ai_helper.prompts.#{prompt.name}", default: nil) ||
              prompt.translated_name || prompt.name

          {
            id: prompt.id,
            name: prompt.name,
            translated_name: translation,
            prompt_type: prompt.prompt_type,
            icon: icon_map(prompt.name),
            location: location_map(prompt.name),
          }
        end
      end

      def generate_and_send_prompt(completion_prompt, input, user)
        llm = DiscourseAi::Completions::LLM.proxy(SiteSetting.ai_helper_model)

        generic_prompt = completion_prompt.messages_with_input(input)

        completion_result = llm.completion!(generic_prompt, user)
        result = { type: completion_prompt.prompt_type }

        result[:diff] = parse_diff(input, completion_result) if completion_prompt.diff?

        result[:suggestions] = (
          if completion_prompt.list?
            parse_list(completion_result)
          else
            [completion_result]
          end
        )

        result
      end

      private

      def icon_map(name)
        case name
        when "translate"
          "language"
        when "generate_titles"
          "heading"
        when "proofread"
          "spell-check"
        when "markdown_table"
          "table"
        when "tone"
          "microphone"
        when "custom_prompt"
          "comment"
        when "rewrite"
          "pen"
        when "explain"
          "question"
        else
          nil
        end
      end

      def location_map(name)
        case name
        when "translate"
          %w[composer post]
        when "generate_titles"
          %w[composer]
        when "proofread"
          %w[composer]
        when "markdown_table"
          %w[composer]
        when "tone"
          %w[composer]
        when "custom_prompt"
          %w[composer]
        when "rewrite"
          %w[composer]
        when "explain"
          %w[post]
        when "summarize"
          %w[post]
        else
          %w[composer post]
        end
      end

      def parse_diff(text, suggestion)
        cooked_text = PrettyText.cook(text)
        cooked_suggestion = PrettyText.cook(suggestion)

        DiscourseDiff.new(cooked_text, cooked_suggestion).inline_html
      end

      def parse_list(list)
        Nokogiri::HTML5.fragment(list).css("item").map(&:text)
      end
    end
  end
end
