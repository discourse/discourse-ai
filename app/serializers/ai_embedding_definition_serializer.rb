# frozen_string_literal: true

class AiEmbeddingDefinitionSerializer < ApplicationSerializer
  root "ai_embedding"

  attributes :id,
             :display_name,
             :dimensions,
             :max_sequence_length,
             :pg_function,
             :provider,
             :url,
             :api_key,
             :tokenizer_class,
             :provider_params
end
