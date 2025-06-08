# frozen_string_literal: true

class AiArtifactKeyValueSerializer < ApplicationSerializer
  attributes :id, :key, :value, :public, :created_at, :updated_at

  has_one :user, serializer: BasicUserSerializer

  def include_value?
    !options[:keys_only]
  end
end
