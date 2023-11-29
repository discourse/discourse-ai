# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class Painter
      def commission_thumbnails(theme, user)
        stable_diffusion_prompt = difussion_prompt(theme, user)

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

      def difussion_prompt(text, user)
        prompt = { insts: <<~TEXT, input: text }
          Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
          You'll find the post between <input></input> XML tags.
        TEXT

        DiscourseAi::Completions::LLM.proxy(SiteSetting.ai_helper_model).completion!(prompt, user)
      end
    end
  end
end
