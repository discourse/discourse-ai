# frozen_string_literal: true

class AiArtifact < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
  validates :html, length: { maximum: 65_535 }
  validates :css, length: { maximum: 65_535 }
  validates :js, length: { maximum: 65_535 }

  def self.iframe_for(id)
    <<~HTML
      <div class='ai-artifact'>
        <iframe src='#{url(id)}' frameborder="0" height="100%" width="100%"></iframe>
        <a href='#{url(id)}' target='_blank'>#{I18n.t("discourse_ai.ai_artifact.link")}</a>
      </div>
    HTML
  end

  def self.url(id)
    Discourse.base_url + "/discourse-ai/ai-bot/artifacts/#{id}"
  end

  def self.share_publicly(id:, post:)
    artifact = AiArtifact.find_by(id: id)
    artifact.update!(metadata: { public: true }) if artifact&.post&.topic&.id == post.topic.id
  end

  def self.unshare_publicly(id:)
    artifact = AiArtifact.find_by(id: id)
    artifact&.update!(metadata: { public: false })
  end

  def url
    self.class.url(id)
  end
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
