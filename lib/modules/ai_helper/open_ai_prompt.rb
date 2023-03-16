# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class OpenAiPrompt
      TRANSLATE = "translate"
      GENERATE_TITLES = "generate_titles"
      PROOFREAD = "proofread"
      VALID_TYPES = [TRANSLATE, GENERATE_TITLES, PROOFREAD]

      def get_prompt_for(prompt_type)
        case prompt_type
        when TRANSLATE
          translate_prompt
        when GENERATE_TITLES
          generate_titles_prompt
        when PROOFREAD
          proofread_prompt
        end
      end

      def generate_and_send_prompt(prompt_type, text)
        result = {}

        prompt = [
          { role: "system", content: get_prompt_for(prompt_type) },
          { role: "user", content: text },
        ]

        result[:suggestions] = DiscourseAi::Inference::OpenAiCompletions
          .perform!(prompt)
          .dig(:choices)
          .to_a
          .flat_map { |choice| parse_content(prompt_type, choice.dig(:message, :content).to_s) }
          .compact_blank

        result[:diff] = generate_diff(text, result[:suggestions].first) if proofreading?(
          prompt_type,
        )

        result
      end

      private

      def proofreading?(prompt_type)
        prompt_type == PROOFREAD
      end

      def generate_diff(text, suggestion)
        cooked_text = PrettyText.cook(text)
        cooked_suggestion = PrettyText.cook(suggestion)

        DiscourseDiff.new(cooked_text, cooked_suggestion).inline_html
      end

      def parse_content(type, content)
        return "" if content.blank?
        return content.strip if type != GENERATE_TITLES

        content.gsub("\"", "").gsub(/\d./, "").split("\n").map(&:strip)
      end

      def translate_prompt
        <<~STRING
          I want you to act as an English translator, spelling corrector and improver. I will speak to you
          in any language and you will detect the language, translate it and answer in the corrected and 
          improved version of my text, in English. I want you to replace my simplified A0-level words and 
          sentences with more beautiful and elegant, upper level English words and sentences. 
          Keep the meaning same, but make them more literary. I want you to only reply the correction, 
          the improvements and nothing else, do not write explanations.
        STRING
      end

      def generate_titles_prompt
        <<~STRING
          I want you to act as a title generator for written pieces. I will provide you with a text, 
          and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
          and ensure that the meaning is maintained. Replies will utilize the language type of the topic. 
        STRING
      end

      def proofread_prompt
        <<~STRING
          I want you act as a proofreader. I will provide you with a text and I want you to review them for any spelling, 
          grammar, or punctuation errors. Once you have finished reviewing the text, provide me with any necessary 
          corrections or suggestions for improve the text.
        STRING
      end
    end
  end
end
