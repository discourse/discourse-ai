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

    def indexing_status(persona, uploads)
      truncation = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(truncation)

      embeddings_table = vector_rep.rag_fragments_table_name

      results = DB.query(<<~SQL, persona_id: persona.id, upload_ids: uploads.map(&:id))
        SELECT
          uploads.id,
          SUM(CASE WHEN (rdf.upload_id IS NOT NULL) THEN 1 ELSE 0 END) AS total,
          SUM(CASE WHEN (eft.rag_document_fragment_id IS NOT NULL) THEN 1 ELSE 0 END) as indexed,
          SUM(CASE WHEN (rdf.upload_id IS NOT NULL AND eft.rag_document_fragment_id IS NULL) THEN 1 ELSE 0 END) as left
        FROM uploads
        LEFT OUTER JOIN rag_document_fragments rdf ON uploads.id = rdf.upload_id AND rdf.ai_persona_id = :persona_id
        LEFT OUTER JOIN #{embeddings_table} eft ON rdf.id = eft.rag_document_fragment_id
        WHERE uploads.id IN (:upload_ids)
        GROUP BY uploads.id
      SQL

      results.reduce({}) do |acc, r|
        acc[r.id] = { total: r.total, indexed: r.indexed, left: r.left }
        acc
      end
    end

    def publish_status(upload, status)
      MessageBus.publish(
        "/discourse-ai/ai-persona-rag/#{upload.id}",
        status,
        user_ids: [upload.user_id],
      )
    end
  end
end

# == Schema Information
#
# Table name: rag_document_fragments
#
#  id              :bigint           not null, primary key
#  fragment        :text             not null
#  upload_id       :integer          not null
#  ai_persona_id   :integer          not null
#  fragment_number :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  metadata        :text
#
