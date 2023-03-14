# frozen_string_literal: true

class AiChatChannelSerializer < ApplicationSerializer
  attributes :id, :chatable, :chatable_type, :chatable_url, :title, :slug
end
