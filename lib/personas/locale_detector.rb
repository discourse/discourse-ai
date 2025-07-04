# frozen_string_literal: true

module DiscourseAi
  module Personas
    class LocaleDetector < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You will be given a piece of text, and your task is to detect the locale (language) of the text and return it in a specific JSON format.

          To complete this task, follow these steps:

          1. Carefully read and analyze the provided text.
          2. Determine the language of the text based on its characteristics, such as vocabulary, grammar, and sentence structure.
          3. Do not use links or programming code in the text to detect the locale
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

          5. Avoid using `und` and prefer `en` over `en-US` or `en-GB` unless the text specifically indicates a regional variant.

          6. Format your response as a JSON object with a single key "locale" and the value as the language code.

          Your output should be in the following format:
          <output>
          {"locale": "xx"}
          </output>

          Where "xx" is replaced by the appropriate language code.

          Important: Base your analysis solely on the provided text. Do not use any external information or make assumptions about the text's origin or context beyond what is explicitly provided.
        PROMPT
      end

      def response_format
        [{ "key" => "locale", "type" => "string" }]
      end

      def temperature
        0
      end

      def examples
        spanish = <<~MARKDOWN
          [quote]
          Non smettere mai di credere nella bellezza dei tuoi sogni. Anche quando tutto sembra perduto, c'è sempre una luce che aspetta di essere trovata.

          Ogni passo, anche il più piccolo, ti avvicina a ciò che desideri. La forza che cerchi è già dentro di te.
          [/quote]

          ¿Cuál es el mensaje principal de esta cita?
        MARKDOWN

        [
          ["Can you tell me what '私の世界で一番好きな食べ物はちらし丼です' means?", { locale: "en" }.to_json],
          [spanish, { locale: "es" }.to_json],
        ]
      end
    end
  end
end
