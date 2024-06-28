# frozen_string_literal: true

class AiCustomToolListSerializer < ApplicationSerializer
  attributes :meta

  has_many :ai_tools, serializer: AiCustomToolSerializer, embed: :objects

  def meta
    { presets: AiTool.presets }
  end

  def ai_tools
    object[:ai_tools]
  end
end
