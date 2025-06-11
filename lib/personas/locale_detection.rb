# frozen_string_literal: true

module DiscourseAi
  module Personas
    class LocaleDetection < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You will be given a piece of text, and your task is to detect the locale (language) of the text and return it in a specific JSON format.

          To complete this task, follow these steps:

          1. Carefully read and analyze the provided text.
          2. Determine the language of the text based on its characteristics, such as vocabulary, grammar, and sentence structure.
          3. Do not use links or programing code in the text to detect the locale
          4. Identify the appropriate language code for the detected language.

          Here is a list of common language codes for reference:
          - English: en
          - Spanish: es
          - French: fr
          - German: de
          - Italian: it
          - Brazilian Portuguese: pt-BR
          - Russian: ru
          - Simplified Chinese: zh-CN
          - Japanese: ja
          - Korean: ko

          If the language is not in this list, use the appropriate IETF language tag code.

          5. Format your response as a JSON object with a single key "locale" and the value as the language code.

          Your output should be in the following format:
          <output>
          {"locale": "xx"}
          </output>

          Where "xx" is replaced by the appropriate language code.

          Important: Base your analysis solely on the provided text. Do not use any external information or make assumptions about the text's origin or context beyond what is explicitly provided.
        PROMPT
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

      def temperature
        0
      end
    end
  end
end
