# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class Image < Tool
        def self.signature
          {
            name: name,
            description:
              "Renders an image from the description (remove all connector words, keep it to 40 words or less). Despite being a text based bot you can generate images! (when user asks to draw, paint or other synonyms try this)",
            parameters: [
              {
                name: "prompts",
                description:
                  "The prompts used to generate or create or draw the image (40 words or less, be creative) up to 4 prompts",
                type: "array",
                item_type: "string",
                required: true,
              },
              {
                name: "seeds",
                description:
                  "The seed used to generate the image (optional) - can be used to retain image style on amended prompts",
                type: "array",
                item_type: "integer",
                required: true,
              },
            ],
          }
        end

        def self.name
          "image"
        end

        def prompts
          parameters[:prompts]
        end

        def seeds
          parameters[:seeds]
        end

        def chain_next_response?
          false
        end

        def invoke(bot_user, _llm)
          # max 4 prompts
          selected_prompts = prompts.take(4)
          seeds = seeds.take(4) if seeds

          progress = +""
          yield(progress)

          results = nil

          # this ensures multisite safety since background threads
          # generate the images
          api_key = SiteSetting.ai_stability_api_key
          engine = SiteSetting.ai_stability_engine
          api_url = SiteSetting.ai_stability_api_url

          threads = []
          selected_prompts.each_with_index do |prompt, index|
            seed = seeds ? seeds[index] : nil
            threads << Thread.new(seed, prompt) do |inner_seed, inner_prompt|
              attempts = 0
              begin
                DiscourseAi::Inference::StabilityGenerator.perform!(
                  inner_prompt,
                  engine: engine,
                  api_key: api_key,
                  api_url: api_url,
                  image_count: 1,
                  seed: inner_seed,
                )
              rescue => e
                attempts += 1
                retry if attempts < 3
                Rails.logger.warn("Failed to generate image for prompt #{prompt}: #{e}")
                nil
              end
            end
          end

          while true
            progress << "."
            yield(progress)
            break if threads.all? { |t| t.join(2) }
          end

          results = threads.map(&:value).compact

          if !results.present?
            return { prompts: prompts, error: "Something went wrong, could not generate image" }
          end

          uploads = []

          results.each_with_index do |result, index|
            result[:artifacts].each do |image|
              Tempfile.create("v1_txt2img_#{index}.png") do |file|
                file.binmode
                file.write(Base64.decode64(image[:base64]))
                file.rewind
                uploads << {
                  prompt: prompts[index],
                  upload: UploadCreator.new(file, "image.png").create_for(bot_user.id),
                  seed: image[:seed],
                }
              end
            end
          end

          @custom_raw = <<~RAW
    
          [grid]
          #{
            uploads
              .map do |item|
                "![#{item[:prompt].gsub(/\|\'\"/, "")}|512x512, 50%](#{item[:upload].short_url})"
              end
              .join(" ")
          }
          [/grid]
        RAW

          {
            prompts: uploads.map { |item| item[:prompt] },
            seeds: uploads.map { |item| item[:seed] },
          }
        end

        protected

        def description_args
          { prompt: prompts.first }
        end
      end
    end
  end
end
