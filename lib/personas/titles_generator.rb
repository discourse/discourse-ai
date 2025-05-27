# frozen_string_literal: true

module DiscourseAi
  module Personas
    class TitlesGenerator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          I want you to act as a title generator for written pieces. I will provide you with a text,
          and you will generate five titles. Please keep the title concise and under 20 words,
          and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
          I want you to only reply the list of options and nothing else, do not write explanations.
          Never ever use colons in the title. Always use sentence case, using a capital letter at
          the start of the title, never start the title with a lower case letter. Proper nouns in the title
          can have a capital letter, and acronyms like LLM can use capital letters. Format some titles
          as questions, some as statements. Make sure to use question marks if the title is a question.
          You will find the text between <input></input> XML tags.
          Wrap each title between <item></item> XML tags.
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end

      def examples
        [
          [
            "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
            "<item>The solitary horse</item><item>The horse etched in gold</item><item>A horse's infinite journey</item><item>A horse lost in time</item><item>A horse's last ride</item>",
          ],
        ]
      end
    end
  end
end
