# frozen_string_literal: true

module ::Jobs
  class DigestRagUpload < ::Jobs::Base
    # TODO(roman): Add a way to automatically recover from errors, resulting in unindexed uploads.
    def execute(args)
      return if (upload = Upload.find_by(id: args[:upload_id])).nil?
      return if (ai_persona = AiPersona.find_by(id: args[:ai_persona_id])).nil?

      fragment_ids = RagDocumentFragment.where(ai_persona: ai_persona, upload: upload).pluck(:id)

      # Check if this is the first time we process this upload.
      if fragment_ids.empty?
        document = get_uploaded_file(upload)
        return if document.nil?

        chunk_size = 1024
        chunk_overlap = 64
        chunks = []
        overlap = ""

        splitter =
          Baran::RecursiveCharacterTextSplitter.new(
            chunk_size: chunk_size,
            chunk_overlap: chunk_overlap,
            separators: ["\n\n", "\n", " ", ""],
          )

        while raw_text = document.read(2048)
          splitter.chunks(overlap + raw_text).each { |chunk| chunks << chunk[:text] }

          overlap = chunks.last[-chunk_overlap..-1] || chunks.last
        end

        ActiveRecord::Base.transaction do
          fragment_ids =
            chunks.each_with_index.map do |fragment_text, idx|
              RagDocumentFragment.create!(
                ai_persona: ai_persona,
                fragment: Encodings.to_utf8(fragment_text),
                fragment_number: idx + 1,
                upload: upload,
              ).id
            end
        end
      end

      fragment_ids.each_slice(50) do |slice|
        Jobs.enqueue(:generate_rag_embeddings, fragment_ids: slice)
      end
    end

    private

    def get_uploaded_file(upload)
      store = Discourse.store
      @file ||=
        if store.external?
          # Upload#filesize could be approximate.
          # add two extra Mbs to make sure that we'll be able to download the upload.
          max_filesize = upload.filesize + 2.megabytes
          store.download(upload, max_file_size_kb: max_filesize)
        else
          File.open(store.path_for(upload))
        end
    end
  end
end
