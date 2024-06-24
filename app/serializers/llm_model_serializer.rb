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
             :enabled_chat_bot,
             :shadowed_by_srv,
             :provider_params

  has_one :user, serializer: BasicUserSerializer, embed: :object

  def shadowed_by_srv
    object.url == LlmModel::RESERVED_VLLM_SRV_URL
  end
end
