# frozen_string_literal: true

Fabricator(:llm_model) do
  display_name "A good model"
  name "gpt-4-turbo"
  provider "open_ai"
  tokenizer "DiscourseAi::Tokenizers::OpenAi"
  max_prompt_tokens 32_000
end
