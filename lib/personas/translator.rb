# frozen_string_literal: true

module DiscourseAi
  module Personas
    class Translator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          I want you to act as an {user_language} translator, spelling corrector and improver. I will write to you
          in any language and you will detect the language, translate it and answer in the corrected and
          improved version of my text, in {user_language}. I want you to replace my simplified A0-level words and
          sentences with more beautiful and elegant, upper level {user_language} words and sentences.
          Keep the meaning same, but make them more literary. I want you to only reply the correction,
          the improvements and nothing else, do not write explanations.
          You will find the text between <input></input> XML tags.
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end

      def temperature
        0.2
      end
    end
  end
end
