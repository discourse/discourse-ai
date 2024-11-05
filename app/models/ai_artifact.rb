# frozen_string_literal: true

class AiArtifact < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
end

# == Schema Information
#
# Table name: ai_artifacts
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  post_id    :integer          not null
#  name       :string(255)      not null
#  html       :string(65535)
#  css        :string(65535)
#  js         :string(65535)
#  metadata   :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
