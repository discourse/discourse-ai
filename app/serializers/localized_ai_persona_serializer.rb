# frozen_string_literal: true

class LocalizedAiPersonaSerializer < ApplicationSerializer
  root "ai_persona"

  attributes :id,
             :name,
             :description,
             :enabled,
             :system,
             :priority,
             :commands,
             :system_prompt,
             :allowed_group_ids,
             :temperature,
             :top_p,
             :mentionable,
             :default_llm,
             :user_id,
             :max_context_posts,
             :vision_enabled,
             :vision_max_pixels,
             :rag_chunk_tokens,
             :rag_chunk_overlap_tokens,
             :rag_conversation_chunks,
             :question_consolidator_llm,
             :allow_chat

  has_one :user, serializer: BasicUserSerializer, embed: :object
  has_many :rag_uploads, serializer: UploadSerializer, embed: :object

  def rag_uploads
    object.uploads
  end

  def name
    object.class_instance.name
  end

  def description
    object.class_instance.description
  end
end
