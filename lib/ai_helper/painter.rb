# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class Painter
      def commission_thumbnails(input, user)
        return [] if input.blank?

        model = SiteSetting.ai_helper_illustrate_post_model
        attribution = "discourse_ai.ai_helper.painter.attribution.#{model}"

        if model == "stable_diffusion_xl"
          stable_diffusion_prompt = difussion_prompt(input, user)
          return [] if stable_diffusion_prompt.blank?

          artifacts =
            DiscourseAi::Inference::StabilityGenerator
              .perform!(stable_diffusion_prompt)
              .dig(:artifacts)
              .to_a
              .map { |art| art[:base64] }

          base64_to_image(artifacts, user.id)
        elsif model == "dall_e_3"
          api_key = SiteSetting.ai_openai_api_key
          api_url = SiteSetting.ai_openai_dall_e_3_url

          artifacts =
            DiscourseAi::Inference::OpenAiImageGenerator
              .perform!(input, api_key: api_key, api_url: api_url)
              .dig(:data)
              .to_a
              .map { |art| art[:b64_json] }

          base64_to_image(artifacts, user.id)
        end
      end

      private

      def base64_to_image(artifacts, user_id)
        attribution =
          I18n.t(
            "discourse_ai.ai_helper.painter.attribution.#{SiteSetting.ai_helper_illustrate_post_model}",
          )

        artifacts.each_with_index.map do |art, i|
          f = Tempfile.new("v1_txt2img_#{i}.png")
          f.binmode
          f.write(Base64.decode64(art))
          f.rewind
          upload = UploadCreator.new(f, attribution).create_for(user_id)
          f.unlink

          UploadSerializer.new(upload, root: false)
        end
      end

      def difussion_prompt(text, user)
        prompt = { insts: <<~TEXT, input: text }
          Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
          You'll find the post between <input></input> XML tags.
        TEXT

        DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
          prompt,
          user: user,
        )
      end
    end
  end
end
