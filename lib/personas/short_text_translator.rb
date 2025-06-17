# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ShortTextTranslator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a translation service specializing in translating short pieces of text or a few words.
          These words may be things like a name, description, or title. Adhere to the following guidelines:

          1. Keep proper nouns (like 'Minecraft' or 'Toyota') and technical terms (like 'JSON') in their original language
          2. Keep the translated content close to the original length
          3. Translation maintains the original meaning
          4. Preserve any Markdown, HTML elements, links, parenthesis, or newlines

          The text to translate will be provided in JSON format with the following structure:
          {"content": "Text to translate", "target_locale": "Target language code"}

          Provide your translation in the following JSON format:
          {"translation": "target_locale translation here"}

          Translate the text now and provide your answer in the specified JSON format.
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
          [{ content: "Japan", target_locale: "es" }.to_json, { translation: "Japón" }.to_json],
          [
            { content: "Cats and Dogs", target_locale: "zh_CN" }.to_json,
            { translation: "猫和狗" }.to_json,
          ],
          [
            { content: "Q&A", target_locale: "pt" }.to_json,
            { translation: "Perguntas e Respostas" }.to_json,
          ],
          [
            { content: "Minecraft", target_locale: "fr" }.to_json,
            { translation: "Minecraft" }.to_json,
          ],
        ]
      end
    end
  end
end
