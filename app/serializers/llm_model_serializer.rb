# frozen_string_literal: true

class LlmModelSerializer < ApplicationSerializer
  root "llm"

  attributes :id, :display_name, :name, :provider, :max_prompt_tokens, :tokenizer
end
