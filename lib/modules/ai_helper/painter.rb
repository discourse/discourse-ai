# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class Painter
      def commission_thumbnails(theme, user)
        stable_diffusion_prompt = difussion_prompt(theme)

        return [] if stable_diffusion_prompt.blank?

        base64_artifacts =
          DiscourseAi::Inference::StabilityGenerator
            .perform!(stable_diffusion_prompt)
            .dig(:artifacts)
            .to_a
            .map { |art| art[:base64] }

        base64_artifacts.each_with_index.map do |artifact, i|
          f = Tempfile.new("v1_txt2img_#{i}.png")
          f.binmode
          f.write(Base64.decode64(artifact))
          f.rewind
          upload = UploadCreator.new(f, "ai_helper_image.png").create_for(user.id)
          f.unlink

          upload.short_url
        end
      end

      private

      def difussion_prompt(text)
        llm_prompt = LlmPrompt.new
        prompt_for_provider =
          completion_prompts.find { |prompt| prompt.provider == llm_prompt.enabled_provider }

        return "" if prompt_for_provider.nil?

        llm_prompt
          .generate_and_send_prompt(prompt_for_provider, { text: text })
          .dig(:suggestions)
          .first
      end

      def completion_prompts
        [
          CompletionPrompt.new(
            provider: "anthropic",
            prompt_type: CompletionPrompt.prompt_types[:text],
            messages: [{ role: "Human", content: <<~TEXT }],
            Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative. 
            The post is provided between <input> tags and the Stable Diffusion prompt string should be returned between <ai> tags.
          TEXT
          ),
          CompletionPrompt.new(
            provider: "openai",
            prompt_type: CompletionPrompt.prompt_types[:text],
            messages: [{ role: "system", content: <<~TEXT }],
            Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
          TEXT
          ),
          CompletionPrompt.new(
            provider: "huggingface",
            prompt_type: CompletionPrompt.prompt_types[:text],
            messages: [<<~TEXT],
            ### System:
            Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
          
            ### User:
            {{user_input}}
      
            ### Assistant:
            Here is a StableDiffusion prompt:
          TEXT
          ),
        ]
      end
    end
  end
end
