# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class DallE < Tool
        def self.signature
          {
            name: name,
            description: "Renders images from supplied descriptions",
            parameters: [
              {
                name: "prompts",
                description:
                  "The prompts used to generate or create or draw the image (5000 chars or less, be creative) up to 4 prompts",
                type: "array",
                item_type: "string",
                required: true,
              },
              {
                name: "aspect_ratio",
                description: "The aspect ratio (optional, square by default)",
                type: "string",
                required: false,
                enum: %w[tall square wide],
              },
            ],
          }
        end

        def self.name
          "dall_e"
        end

        def prompts
          parameters[:prompts]
        end

        def aspect_ratio
          parameters[:aspect_ratio]
        end

        def chain_next_response?
          false
        end

        def invoke
          # max 4 prompts
          max_prompts = prompts.take(4)
          progress = prompts.first

          yield(progress)

          results = nil

          # this ensures multisite safety since background threads
          # generate the images
          api_key = SiteSetting.ai_openai_api_key
          api_url = SiteSetting.ai_openai_dall_e_3_url

          size = "1024x1024"
          if aspect_ratio == "tall"
            size = "1024x1792"
          elsif aspect_ratio == "wide"
            size = "1792x1024"
          end

          threads = []
          max_prompts.each_with_index do |prompt, index|
            threads << Thread.new(prompt) do |inner_prompt|
              attempts = 0
              begin
                DiscourseAi::Inference::OpenAiImageGenerator.perform!(
                  inner_prompt,
                  size: size,
                  api_key: api_key,
                  api_url: api_url,
                )
              rescue => e
                attempts += 1
                sleep 2
                retry if attempts < 3
                Discourse.warn_exception(
                  e,
                  message: "Failed to generate image for prompt #{prompt}",
                )
                nil
              end
            end
          end

          break if threads.all? { |t| t.join(2) } while true

          results = threads.filter_map(&:value)

          if results.blank?
            return { prompts: max_prompts, error: "Something went wrong, could not generate image" }
          end

          uploads = []

          results.each_with_index do |result, index|
            result[:data].each do |image|
              Tempfile.create("v1_txt2img_#{index}.png") do |file|
                file.binmode
                file.write(Base64.decode64(image[:b64_json]))
                file.rewind
                uploads << {
                  prompt: image[:revised_prompt],
                  upload:
                    UploadCreator.new(
                      file,
                      "image.png",
                      for_private_message: context[:private_message],
                    ).create_for(bot_user.id),
                }
              end
            end
          end

          self.custom_raw = <<~RAW

            [grid]
            #{
            uploads
              .map { |item| "![#{item[:prompt].gsub(/\|\'\"/, "")}](#{item[:upload].short_url})" }
              .join(" ")
          }
            [/grid]
          RAW

          { prompts: uploads.map { |item| item[:prompt] } }
        end

        protected

        def description_args
          { prompt: prompts.first }
        end
      end
    end
  end
end
