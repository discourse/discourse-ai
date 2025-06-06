# frozen_string_literal: true

module DiscourseAi
  module Translation
    class ShortTextTranslator < BaseTranslator
      PROMPT_TEMPLATE = <<~TEXT.freeze
      You are a translation service specializing in translating short pieces of text or a few words.
      These words may be things like a name, description, or title. Adhere to the following guidelines:

      1. Keep proper nouns and technical terms in their original language
      2. Keep the translated content close to the original length
      3. Translation maintains the original meaning
      4. Preserving any Markdown, HTML elements, links, parenthesis, or newlines

      Provide your translation in the following JSON format:

      <output>
      {"translation": "target_locale translation here"}
      </output>

      Here are three examples of correct translation

      Original: {"content":"Japan", "target_locale":"es"}
      Correct translation: {"translation": "Japón"}

      Original: {"name":"Cats and Dogs", "target_locale":"zh_CN"}
      Correct translation: {"translation": "猫和狗"}

      Original: {"name": "Q&A", "target_locale": "pt"}
      Correct translation: {"translation": "Perguntas e Respostas"}

      Remember to keep proper nouns like "Minecraft" and "Toyota" in their original form. Translate the text now and provide your answer in the specified JSON format.
    TEXT

      private def prompt_template
        PROMPT_TEMPLATE
      end
    end
  end
end
