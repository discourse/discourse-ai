# frozen_string_literal: true

class LlmModelSerializer < ApplicationSerializer
  root "llm"

  attributes :id,
             :display_name,
             :name,
             :provider,
             :max_prompt_tokens,
             :tokenizer,
             :api_key,
             :url,
             :enabled_chat_bot
end
