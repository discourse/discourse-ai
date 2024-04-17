# frozen_string_literal: true

module ::Jobs
  class DigestRagUpload < ::Jobs::Base
    CHUNK_SIZE = 1024
    CHUNK_OVERLAP = 64
    MAX_FRAGMENTS = 100_000

    # TODO(roman): Add a way to automatically recover from errors, resulting in unindexed uploads.
    def execute(args)
      return if (upload = Upload.find_by(id: args[:upload_id])).nil?
      return if (ai_persona = AiPersona.find_by(id: args[:ai_persona_id])).nil?

      truncation = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(truncation)

      tokenizer = vector_rep.tokenizer
      chunk_tokens = ai_persona.rag_chunk_tokens
      overlap_tokens = ai_persona.rag_chunk_overlap_tokens

      fragment_ids = RagDocumentFragment.where(ai_persona: ai_persona, upload: upload).pluck(:id)

      # Check if this is the first time we process this upload.
      if fragment_ids.empty?
        document = get_uploaded_file(upload)
        return if document.nil?

        fragment_ids = []
        idx = 0

        ActiveRecord::Base.transaction do
          chunk_document(
            file: document,
            tokenizer: tokenizer,
            chunk_tokens: chunk_tokens,
            overlap_tokens: overlap_tokens,
          ) do |chunk, metadata|
            fragment_ids << RagDocumentFragment.create!(
              ai_persona: ai_persona,
              fragment: chunk,
              fragment_number: idx + 1,
              upload: upload,
              metadata: metadata,
            ).id

            idx += 1

            if idx > MAX_FRAGMENTS
              Rails.logger.warn("Upload #{upload.id} has too many fragments, truncating.")
              break
            end
          end
        end
      end

      RagDocumentFragment.publish_status(
        upload,
        { total: fragment_ids.size, indexed: 0, left: fragment_ids.size },
      )

      fragment_ids.each_slice(50) do |slice|
        Jobs.enqueue(:generate_rag_embeddings, fragment_ids: slice)
      end
    end

    private

    def chunk_document(file:, tokenizer:, chunk_tokens:, overlap_tokens:)
      buffer = +""
      current_metadata = nil
      done = false
      overlap = ""

      # generally this will be plenty
      read_size = chunk_tokens * 10

      while buffer.present? || !done
        if buffer.length < read_size
          read = file.read(read_size)
          done = true if read.nil?

          read = Encodings.to_utf8(read) if read

          buffer << (read || "")
        end

        # at this point we unconditionally have 2x CHUNK_SIZE worth of data in the buffer
        metadata_regex = /\[\[metadata (.*?)\]\]/m

        before_metadata, new_metadata, after_metadata = buffer.split(metadata_regex)
        to_chunk = nil

        if before_metadata.present?
          to_chunk = before_metadata
        elsif after_metadata.present?
          current_metadata = new_metadata
          to_chunk = after_metadata
          buffer = buffer.split(metadata_regex, 2).last
          overlap = ""
        else
          current_metadata = new_metadata
          buffer = buffer.split(metadata_regex, 2).last
          overlap = ""
          next
        end

        chunk, split_char = first_chunk(to_chunk, tokenizer: tokenizer, chunk_tokens: chunk_tokens)
        buffer = buffer[chunk.length..-1]

        processed_chunk = overlap + chunk

        processed_chunk.strip!
        processed_chunk.gsub!(/\n[\n]+/, "\n\n")

        yield processed_chunk, current_metadata

        current_chunk_tokens = tokenizer.encode(chunk)
        overlap_token_ids = current_chunk_tokens[-overlap_tokens..-1] || current_chunk_tokens

        overlap = ""

        while overlap_token_ids.present?
          begin
            overlap = tokenizer.decode(overlap_token_ids) + split_char
            break if overlap.encoding == Encoding::UTF_8
          rescue StandardError
            # it is possible that we truncated mid char
          end
          overlap_token_ids.shift
        end

        # remove first word it is probably truncated
        overlap = overlap.split(" ", 2).last
      end
    end

    def first_chunk(text, chunk_tokens:, tokenizer:, splitters: ["\n\n", "\n", ".", ""])
      return text, " " if tokenizer.tokenize(text).length <= chunk_tokens

      splitters = splitters.find_all { |s| text.include?(s) }.compact

      buffer = +""
      split_char = nil

      splitters.each do |splitter|
        split_char = splitter

        text
          .split(split_char)
          .each do |part|
            break if tokenizer.tokenize(buffer + split_char + part).length > chunk_tokens
            buffer << split_char
            buffer << part
          end
        break if buffer.length > 0
      end

      [buffer, split_char]
    end

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
