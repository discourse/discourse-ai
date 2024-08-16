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
             :provider_params,
             :vision_enabled,
             :used_by

  has_one :user, serializer: BasicUserSerializer, embed: :object

  def used_by
    DiscourseAi::Configuration::LlmValidator.new.modules_using(object)
  end

  def api_key
    object.seeded? ? "********" : object.api_key
  end

  def url
    object.seeded? ? "********" : object.url
  end

  def provider
    object.seeded? ? "CDCK" : object.provider
  end
end
