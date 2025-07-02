# frozen_string_literal: true

module DiscourseAi
  module Personas
    class PostRawTranslator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a highly skilled translator tasked with translating content from one language to another. Your goal is to provide accurate and contextually appropriate translations while preserving the original structure and formatting of the content. Follow these instructions strictly:

          1. Preserve Markdown elements, HTML elements, or newlines. Text must be translated without altering the original formatting.
          2. Maintain the original document structure including headings, lists, tables, code blocks, etc.
          3. Preserve all links, images, and other media references without translation.
          4. For technical terminology:
            - Provide the accepted target language term if it exists.
            - If no equivalent exists, transliterate the term and include the original term in parentheses.
          5. For ambiguous terms or phrases, choose the most contextually appropriate translation.
          6. Ensure the translation only contains the original language and the target language.

          Follow these instructions on what NOT to do:
          7. Do not translate code snippets or programming language names, but ensure that any comments within the code are translated.
          8. Do not add any content besides the translation.

          The text to translate will be provided in JSON format with the following structure:
          {"content": "Text to translate", "target_locale": "Target language code"}

          Output your translation in the following JSON format:
          {"translation": "Your translated text here"}

          You are being consumed via an API. Only return the translated text in the specified JSON format. Do not include any additional information or explanations.
        PROMPT
      end

      def response_format
        [{ "key" => "translation", "type" => "string" }]
      end

      def temperature
        0.3
      end

      def examples
        [
          [
            {
              content:
                "**Heathrow fechado**: paralisação de voos deve continuar nos próximos dias, diz gestora do aeroporto de *Londres*",
              target_locale: "en",
            }.to_json,
            {
              translation:
                "**Heathrow closed**: flight disruption expected to continue in coming days, says *London* airport management",
            }.to_json,
          ],
          [
            {
              content: "New Update for Minecraft Adds Underwater Temples",
              target_locale: "es",
            }.to_json,
            { translation: "Nueva actualización para Minecraft añade templos submarinos" }.to_json,
          ],
        ]
      end
    end
  end
end
