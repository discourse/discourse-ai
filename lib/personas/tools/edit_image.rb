# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class EditImage < Tool
        def self.signature
          {
            name: name,
            description: "Renders images from supplied descriptions",
            parameters: [
              {
                name: "prompt",
                description:
                  "instructions for the image to be edited (5000 chars or less, be creative)",
                type: "string",
                required: true,
              },
              {
                name: "image_urls",
                description:
                  "The images to provides as context for the edit (minimum 1, maximum 10), use the short url eg: upload://qUm0DGR49PAZshIi7HxMd3cAlzn.png",
                type: "array",
                item_type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "edit_image"
        end

        def prompt
          parameters[:prompt]
        end

        def chain_next_response?
          false
        end

        def image_urls
          parameters[:image_urls]
        end

        def invoke
          yield(prompt)

          return { prompt: prompt, error: "No valid images provided" } if image_urls.blank?

          uploads =
            image_urls
              .map do |url|
                sha1 = Upload.sha1_from_short_url(url)
                Upload.find_by(sha1: sha1)
              end
              .compact
              .take(10)

          return { prompt: prompt, error: "No valid images provided" } if uploads.blank?

          result =
            DiscourseAi::Inference::OpenAiImageGenerator.create_edited_upload!(
              uploads,
              prompt,
              user_id: bot_user.id,
            )

          if result.blank?
            return { prompt: prompt, error: "Something went wrong, could not generate image" }
          end

          self.custom_raw = "![#{result[:prompt].gsub(/\|\'\"/, "")}](#{result[:upload].short_url})"

          { prompt: result[:prompt], url: result[:upload].short_url }
        end

        protected

        def description_args
          { prompt: prompt }
        end
      end
    end
  end
end
