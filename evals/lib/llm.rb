# frozen_string_literal: true

module DiscourseAi::Evals
end

class DiscourseAi::Evals::Llm
  CONFIGS = {
    "gpt-4o" => {
      display_name: "GPT-4o",
      name: "gpt-4o",
      tokenizer: "DiscourseAi::Tokenizer::OpenAiTokenizer",
      api_key_env: "OPENAI_API_KEY",
      provider: "open_ai",
      url: "https://api.openai.com/v1/chat/completions",
      max_prompt_tokens: 131_072,
      vision_enabled: true,
    },
    "gpt-4o-mini" => {
      display_name: "GPT-4o-mini",
      name: "gpt-4o-mini",
      tokenizer: "DiscourseAi::Tokenizer::OpenAiTokenizer",
      api_key_env: "OPENAI_API_KEY",
      provider: "open_ai",
      url: "https://api.openai.com/v1/chat/completions",
      max_prompt_tokens: 131_072,
      vision_enabled: true,
    },
    "claude-3.5-haiku" => {
      display_name: "Claude 3.5 Haiku",
      name: "claude-3-5-haiku-latest",
      tokenizer: "DiscourseAi::Tokenizer::AnthropicTokenizer",
      api_key_env: "ANTHROPIC_API_KEY",
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      max_prompt_tokens: 200_000,
      vision_enabled: false,
    },
    "claude-3.5-sonnet" => {
      display_name: "Claude 3.5 Sonnet",
      name: "claude-3-5-sonnet-latest",
      tokenizer: "DiscourseAi::Tokenizer::AnthropicTokenizer",
      api_key_env: "ANTHROPIC_API_KEY",
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      max_prompt_tokens: 200_000,
      vision_enabled: true,
    },
    "gemini-2.0-flash" => {
      display_name: "Gemini 2.0 Flash",
      name: "gemini-2-0-flash",
      tokenizer: "DiscourseAi::Tokenizer::GeminiTokenizer",
      api_key_env: "GEMINI_API_KEY",
      provider: "google",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash",
      max_prompt_tokens: 1_000_000,
      vision_enabled: true,
    },
    "gemini-2.0-pro-exp" => {
      display_name: "Gemini 2.0 pro",
      name: "gemini-2-0-pro-exp",
      tokenizer: "DiscourseAi::Tokenizer::GeminiTokenizer",
      api_key_env: "GEMINI_API_KEY",
      provider: "google",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-pro-exp",
      max_prompt_tokens: 1_000_000,
      vision_enabled: true,
    },
  }

  def self.choose(config_name)
    if CONFIGS[config_name].nil?
      CONFIGS
        .keys
        .map do |config_name|
          begin
            new(config_name)
          rescue => e
            puts "Error initializing #{config_name}: #{e}"
            nil
          end
        end
        .compact
    elsif !CONFIGS.include?(config_name)
      raise "Invalid llm"
    else
      [new(config_name)]
    end
  end

  attr_reader :llm_model
  attr_reader :llm

  def initialize(config_name)
    config = CONFIGS[config_name].dup
    api_key_env = config.delete(:api_key_env)
    if !ENV[api_key_env]
      raise "Missing API key for #{config_name}, should be set via #{api_key_env}"
    end

    config[:api_key] = ENV[api_key_env]
    @llm_model = LlmModel.new(config)
    @llm = DiscourseAi::Completions::Llm.proxy(@llm_model)
  end

  def eval(type:, args:, expected_output: nil, expected_output_regex: nil)
    result =
      case type
      when "helper"
        helper(**args)
      when "pdf_to_text"
        pdf_to_text(**args)
      end

    if expected_output
      if result == expected_output
        { result: :pass }
      else
        { result: :fail, expected_output: expected_output, actual_output: result }
      end
    elsif expected_output_regex
      expected_output_regex = Regexp.new(expected_output_regex)
      if result.match?(expected_output_regex)
        { result: :pass }
      else
        { result: :fail, expected_output: expected_output_regex, actual_output: result }
      end
    else
      { result: :unknown, actual_output: result }
    end
  end

  def name
    @llm_model.display_name
  end

  def vision?
    @llm_model.vision_enabled
  end

  private

  def pdf_to_text(path:)
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
        .new(upload: page_upload, llm_model: @llm_model, user: Discourse.system_user)
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

  def helper(input:, name:)
    completion_prompt = CompletionPrompt.find_by(name: name)
    helper = DiscourseAi::AiHelper::Assistant.new(helper_llm: @llm)
    result =
      helper.generate_and_send_prompt(
        completion_prompt,
        input,
        current_user = Discourse.system_user,
        _force_default_locale = false,
      )

    result[:suggestions].first
  end
end
