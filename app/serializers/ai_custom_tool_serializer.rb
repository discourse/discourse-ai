# frozen_string_literal: true

class AiCustomToolSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :summary,
             :parameters,
             :script,
             :rag_chunk_tokens,
             :rag_chunk_overlap_tokens,
             :created_by_id,
             :created_at,
             :updated_at

  self.root = "ai_tool"

  has_many :rag_uploads, serializer: UploadSerializer, embed: :object

  def rag_uploads
    object.uploads
  end
end
