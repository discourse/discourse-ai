# frozen_string_literal: true

class AiChatChannelSerializer < ApplicationSerializer
  attributes :id, :chatable, :chatable_type, :chatable_url, :slug

  def title
    # Display all participants for a DM.
    # For category channels, the argument is ignored.
    object.title(nil)
  end
end
