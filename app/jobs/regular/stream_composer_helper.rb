# frozen_string_literal: true

module Jobs
  class StreamComposerHelper < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless args[:prompt]
      return unless user = User.find_by(id: args[:user_id])
      return unless args[:text]

      prompt = CompletionPrompt.enabled_by_name(args[:prompt])

      if prompt.id == CompletionPrompt::CUSTOM_PROMPT
        prompt.custom_instruction = args[:custom_prompt]
      end

      DiscourseAi::AiHelper::Assistant.new.stream_prompt(
        prompt,
        args[:text],
        user,
        "/discourse-ai/ai-helper/stream_composer_suggestion",
        force_default_locale: args[:force_default_locale],
      )
    end
  end
end
