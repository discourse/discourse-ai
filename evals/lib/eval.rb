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
              :expected_output_regex,
              :expected_tool_call

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
    @expected_tool_call = @yaml[:expected_tool_call]
    @expected_tool_call.symbolize_keys! if @expected_tool_call

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
      when "prompt"
        prompt_call(llm, **args)
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
    elsif expected_tool_call
      tool_call = result

      if result.is_a?(Array)
        tool_call = result.find { |r| r.is_a?(DiscourseAi::Completions::ToolCall) }
      end
      if !tool_call.is_a?(DiscourseAi::Completions::ToolCall) ||
           (tool_call.name != expected_tool_call[:name]) ||
           (tool_call.parameters != expected_tool_call[:params])
        { result: :fail, expected_output: expected_tool_call, actual_output: result }
      else
        { result: :pass }
      end
    else
      { result: :unknown, actual_output: result }
    end
  end

  def print
    puts "#{id}: #{description}"
  end

  def to_json
    {
      type: @type,
      path: @path,
      name: @name,
      description: @description,
      id: @id,
      args: @args,
      vision: @vision,
      expected_output: @expected_output,
      expected_output_regex: @expected_output_regex,
    }.compact
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

    text = +""
    DiscourseAi::Utils::PdfToText
      .new(upload: upload, user: Discourse.system_user, llm_model: llm.llm_model)
      .extract_text do |chunk|
        text << chunk if chunk
        text << "\n\n" if chunk
      end

    text
  ensure
    upload.destroy if upload
  end

  def prompt_call(llm, system_prompt:, message:, tools: nil, stream: false)
    if tools
      tools.each do |tool|
        tool.symbolize_keys!
        tool[:parameters].symbolize_keys! if tool[:parameters]
      end
    end
    prompt =
      DiscourseAi::Completions::Prompt.new(
        system_prompt,
        messages: [{ type: :user, content: message }],
        tools: tools,
      )

    result = nil
    if stream
      result = []
      llm
        .llm_model
        .to_llm
        .generate(prompt, user: Discourse.system_user) { |partial| result << partial }
    else
      result = llm.llm_model.to_llm.generate(prompt, user: Discourse.system_user)
    end
    result
  end
end
