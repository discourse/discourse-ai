# frozen_string_literal: true

class RagDocumentFragment < ActiveRecord::Base
  belongs_to :upload
  belongs_to :ai_persona

  class << self
    def link_persona_and_uploads(persona, upload_ids)
      return if persona.blank?
      return if upload_ids.blank?
      return if !SiteSetting.ai_embeddings_enabled?

      UploadReference.ensure_exist!(upload_ids: upload_ids, target: persona)

      upload_ids.each do |upload_id|
        Jobs.enqueue(:digest_rag_upload, ai_persona_id: persona.id, upload_id: upload_id)
      end
    end

    def update_persona_uploads(persona, upload_ids)
      return if persona.blank?
      return if !SiteSetting.ai_embeddings_enabled?

      if upload_ids.blank?
        RagDocumentFragment.where(ai_persona: persona).destroy_all
        UploadReference.where(target: persona).destroy_all
      else
        RagDocumentFragment.where(ai_persona: persona).where.not(upload_id: upload_ids).destroy_all
        link_persona_and_uploads(persona, upload_ids)
      end
    end
  end
end

# == Schema Information
#
# Table name: rag_document_fragments
#
#  id              :bigint           not null, primary key
#  fragment        :text             not null
#  ai_persona_id   :integer          not null
#  upload_id       :integer          not null
#  fragment_number :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
