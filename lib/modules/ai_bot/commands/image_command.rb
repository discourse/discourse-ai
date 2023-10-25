#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class ImageCommand < Command
    class << self
      def name
        "image"
      end

      def desc
        "Renders an image from the description (remove all connector words, keep it to 40 words or less). Despite being a text based bot you can generate images! (when user asks to draw, paint or other synonyms try this)"
      end

      def parameters
        [
          Parameter.new(
            name: "prompt",
            description:
              "The prompt used to generate or create or draw the image (40 words or less, be creative)",
            type: "string",
            required: true,
          ),
        ]
      end
    end

    def result_name
      "results"
    end

    def description_args
      { prompt: @last_prompt }
    end

    def chain_next_response
      false
    end

    def custom_raw
      @custom_raw
    end

    def process(prompt:)
      @last_prompt = prompt

      show_progress(localized_description)

      results = nil

      # this ensures multisite safety since background threads
      # generate the images
      api_key = SiteSetting.ai_stability_api_key
      engine = SiteSetting.ai_stability_engine
      api_url = SiteSetting.ai_stability_api_url

      # API is flaky, so try a few times
      3.times do
        begin
          thread =
            Thread.new do
              begin
                results =
                  DiscourseAi::Inference::StabilityGenerator.perform!(
                    prompt,
                    engine: engine,
                    api_key: api_key,
                    api_url: api_url,
                  )
              rescue => e
                Rails.logger.warn("Failed to generate image for prompt #{prompt}: #{e}")
              end
            end

          show_progress(".", progress_caret: true) while !thread.join(2)

          break if results
        end
      end

      return { prompt: prompt, error: "Something went wrong, could not generate image" } if !results

      uploads = []

      results[:artifacts].each_with_index do |image, i|
        f = Tempfile.new("v1_txt2img_#{i}.png")
        f.binmode
        f.write(Base64.decode64(image[:base64]))
        f.rewind
        uploads << UploadCreator.new(f, "image.png").create_for(bot_user.id)
        f.unlink
      end

      @custom_raw = <<~RAW

      [grid]
      #{
        uploads
          .map { |upload| "![#{prompt.gsub(/\|\'\"/, "")}|512x512, 50%](#{upload.short_url})" }
          .join(" ")
      }
      [/grid]
    RAW

      { prompt: prompt, displayed_to_user: true }
    end
  end
end
