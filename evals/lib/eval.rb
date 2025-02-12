#frozen_string_literal: true

class DiscourseAi::Evals::Eval
  attr_reader :type,
              :path,
              :name,
              :description,
              :id,
              :args,
              :vision,
              :expected_output,
              :expected_output_regex

  def initialize(path:)
    @yaml = YAML.load_file(path).symbolize_keys
    @path = path
    @name = @yaml[:name]
    @id = @yaml[:id]
    @description = @yaml[:description]
    @vision = @yaml[:vision]
    @args = @yaml[:args]&.symbolize_keys
    @type = @yaml[:type]
    @expected_output = @yaml[:expected_output]
    @expected_output_regex = @yaml[:expected_output_regex]
    @expected_output_regex =
      Regexp.new(@expected_output_regex, Regexp::MULTILINE) if @expected_output_regex

    @args[:path] = File.expand_path(File.join(File.dirname(path), @args[:path])) if @args&.key?(
      :path,
    )
  end

  def run(llm:)
    result =
      case type
      when "helper"
        helper(llm, **args)
      when "pdf_to_text"
        pdf_to_text(llm, **args)
      when "image_to_text"
        image_to_text(llm, **args)
      end

    if expected_output
      if result == expected_output
        { result: :pass }
      else
        { result: :fail, expected_output: expected_output, actual_output: result }
      end
    elsif expected_output_regex
      if result.match?(expected_output_regex)
        { result: :pass }
      else
        { result: :fail, expected_output: expected_output_regex, actual_output: result }
      end
    else
      { result: :unknown, actual_output: result }
    end
  end

  def print
    puts "#{id}: #{description}"
  end

  private

  def helper(llm, input:, name:)
    completion_prompt = CompletionPrompt.find_by(name: name)
    helper = DiscourseAi::AiHelper::Assistant.new(helper_llm: llm.llm_proxy)
    result =
      helper.generate_and_send_prompt(
        completion_prompt,
        input,
        current_user = Discourse.system_user,
        _force_default_locale = false,
      )

    result[:suggestions].first
  end

  def image_to_text(llm, path:)
    upload =
      UploadCreator.new(File.open(path), File.basename(path)).create_for(Discourse.system_user.id)

    text = +""
    DiscourseAi::Utils::ImageToText
      .new(upload: upload, llm_model: llm.llm_model, user: Discourse.system_user)
      .extract_text do |chunk, error|
        text << chunk if chunk
        text << "\n\n" if chunk
      end
    text
  ensure
    upload.destroy if upload
  end

  def pdf_to_text(llm, path:)
    upload =
      UploadCreator.new(File.open(path), File.basename(path)).create_for(Discourse.system_user.id)

    uploads =
      DiscourseAi::Utils::PdfToImages.new(
        upload: upload,
        user: Discourse.system_user,
      ).uploaded_pages

    text = +""
    uploads.each do |page_upload|
      DiscourseAi::Utils::ImageToText
        .new(upload: page_upload, llm_model: llm.llm_model, user: Discourse.system_user)
        .extract_text do |chunk, error|
          text << chunk if chunk
          text << "\n\n" if chunk
        end
      upload.destroy
    end

    text
  ensure
    upload.destroy if upload
  end
end
