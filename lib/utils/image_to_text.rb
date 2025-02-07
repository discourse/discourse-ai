# frozen_string_literal: true

class DiscourseAi::Utils::ImageToText
  BACKOFF_SECONDS = [5, 30, 60]

  class Reader
    def initialize(uploads:, llm_model:, user:)
      @uploads = uploads
      @llm_model = llm_model
      @user = user
      @buffer = +""

      @to_process = uploads.dup
    end

    # return nil if no more data
    def read(length)
      # for implementation simplicity we will process one image at a time
      if !@buffer.empty?
        part = @buffer.slice!(0, length)
        return part
      end

      return nil if @to_process.empty?

      upload = @to_process.shift
      extractor =
        DiscourseAi::Utils::ImageToText.new(upload: upload, llm_model: @llm_model, user: @user)
      extractor.extract_text do |chunk, error|
        if error
          Discourse.warn_exception(
            error,
            message: "Discourse AI: Failed to extract text from image",
          )
        else
          # this introduces chunk markers so discourse rag ingestion requires no overlaps
          @buffer << "\n[[metadata ]]\n"
          @buffer << chunk
        end
      end

      read(length)
    end
  end

  def self.as_fake_file(uploads:, llm_model:, user:)
    # given our implementation for extracting text expect a file, return a simple object that can simulate read(size)
    # and stream content
    Reader.new(uploads: uploads, llm_model: llm_model, user: user)
  end

  attr_reader :upload, :llm_model, :user

  def initialize(upload:, llm_model:, user:)
    @upload = upload
    @llm_model = llm_model
    @user = user
  end

  def extract_text(retries: 3)
    uploads ||= @uploaded_pages

    raise "must specify a block" if !block_given?
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
      extracted.each { |chunk| yield(chunk) }
    else
      yield(nil, error)
    end
    extracted || []
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
