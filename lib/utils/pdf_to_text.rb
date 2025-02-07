# frozen_string_literal: true

class DiscourseAi::Utils::PdfToText
  MAX_PDF_SIZE = 100.megabytes
  MAX_CONVERT_SECONDS = 30
  BACKOFF_SECONDS = [5, 30, 60]

  attr_reader :upload, :llm_model, :user

  def initialize(upload:, llm_model:, user:)
    @upload = upload
    @llm_model = llm_model
    @user = user
    @uploaded_pages = UploadReference.where(target: upload).map(&:upload)
  end

  def extract_pages
    temp_dir = File.join(Dir.tmpdir, "discourse-pdf-#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(temp_dir)

    begin
      pdf_path =
        if upload.local?
          Discourse.store.path_for(upload)
        else
          Discourse.store.download_safe(upload, max_file_size_kb: MAX_PDF_SIZE)&.path
        end

      raise Discourse::InvalidParameters.new("Failed to download PDF") if pdf_path.nil?

      temp_pdf = File.join(temp_dir, "source.pdf")
      FileUtils.cp(pdf_path, temp_pdf)

      # Convert PDF to individual page images
      output_pattern = File.join(temp_dir, "page-%04d.png")

      command = [
        "magick",
        "-density",
        "300",
        temp_pdf,
        "-background",
        "white",
        "-auto-orient",
        "-quality",
        "85",
        output_pattern,
      ]

      Discourse::Utils.execute_command(
        *command,
        failure_message: "Failed to convert PDF to images",
        timeout: MAX_CONVERT_SECONDS,
      )

      uploads = []
      Dir
        .glob(File.join(temp_dir, "page-*.png"))
        .sort
        .each do |page_path|
          upload =
            UploadCreator.new(File.open(page_path), "page-#{File.basename(page_path)}").create_for(
              @user.id,
            )

          uploads << upload
        end

      # Create upload references
      UploadReference.ensure_exist!(upload_ids: uploads.map(&:id), target: @upload)

      @uploaded_pages = uploads
    ensure
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    end
  end

  def extract_text(uploads: nil, retries: 3)
    uploads ||= @uploaded_pages

    raise "must specify a block" if !block_given?
    uploads
      .map do |upload|
        extracted = nil
        error = nil

        backoff = BACKOFF_SECONDS.dup

        retries.times do
          seconds = nil
          begin
            extracted = extract_text_from_page(upload)
            break
          rescue => e
            error = e
            seconds = backoff.shift || seconds
            sleep(seconds)
          end
        end
        if extracted
          extracted.each { |chunk| yield(chunk, upload) }
        else
          yield(nil, upload, error)
        end
        extracted || []
      end
      .flatten
  end

  private

  def system_message
    <<~MSG
      OCR the following page into Markdown. Tables should be formatted as Github flavored markdown.
      Do not sorround your output with triple backticks.

      Chunk the document into sections of roughly 250 - 1000 words. Our goal is to identify parts of the page with same semantic theme. These chunks will be embedded and used in a RAG pipeline.

      Always prefer returning text in Markdown vs HTML.
      Describe all the images and graphs you encounter.
      Only return text that will assist in the querying of data. Omit text such as "I had trouble recognizing images" and so on.

      Surround the chunks with <chunk> </chunk> html tags.
    MSG
  end

  def extract_text_from_page(page)
    llm = llm_model.to_llm
    messages = [{ type: :user, content: "process the following page", upload_ids: [page.id] }]
    prompt = DiscourseAi::Completions::Prompt.new(system_message, messages: messages)
    result = llm.generate(prompt, user: Discourse.system_user)
    extract_chunks(result)
  end

  def extract_chunks(text)
    return [] if text.nil? || text.empty?

    if text.include?("<chunk>") && text.include?("</chunk>")
      chunks = []
      remaining_text = text.dup

      while remaining_text.length > 0
        if remaining_text.start_with?("<chunk>")
          # Extract chunk content
          chunk_end = remaining_text.index("</chunk>")
          if chunk_end
            chunk = remaining_text[7..chunk_end - 1].strip
            chunks << chunk unless chunk.empty?
            remaining_text = remaining_text[chunk_end + 8..-1] || ""
          else
            # Malformed chunk - add remaining text and break
            chunks << remaining_text[7..-1].strip
            break
          end
        else
          # Handle text before next chunk if it exists
          next_chunk = remaining_text.index("<chunk>")
          if next_chunk
            text_before = remaining_text[0...next_chunk].strip
            chunks << text_before unless text_before.empty?
            remaining_text = remaining_text[next_chunk..-1]
          else
            # No more chunks - add remaining text and break
            chunks << remaining_text.strip
            break
          end
        end
      end

      return chunks.reject(&:empty?)
    end

    [text]
  end
end
