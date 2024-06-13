# frozen_string_literal: true

Fabricator(:llm_model) do
  display_name "A good model"
  name "gpt-4-turbo"
  provider "open_ai"
  tokenizer "DiscourseAi::Tokenizers::OpenAi"
  max_prompt_tokens 32_000
  bot_username { sequence(:bot_username) { |n| "bot_username_#{n}" } }
end
