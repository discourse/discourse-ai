#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class DallECommand < Command
    class << self
      def name
        "dall_e"
      end

      def desc
        "Renders images from supplied descriptions"
      end

      def parameters
        [
          Parameter.new(
            name: "prompts",
            description:
              "The prompts used to generate or create or draw the image (5000 chars or less, be creative) up to 4 prompts",
            type: "array",
            item_type: "string",
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

    def process(prompts:)
      # max 4 prompts
      prompts = prompts.take(4)

      @last_prompt = prompts[0]

      show_progress(localized_description)

      results = nil

      # this ensures multisite safety since background threads
      # generate the images
      api_key = SiteSetting.ai_openai_api_key
      api_url = SiteSetting.ai_openai_dall_e_3_url

      threads = []
      prompts.each_with_index do |prompt, index|
        threads << Thread.new(prompt) do |inner_prompt|
          attempts = 0
          begin
            DiscourseAi::Inference::OpenAiImageGenerator.perform!(
              inner_prompt,
              api_key: api_key,
              api_url: api_url,
            )
          rescue => e
            attempts += 1
            sleep 2
            retry if attempts < 3
            Discourse.warn_exception(e, message: "Failed to generate image for prompt #{prompt}")
            nil
          end
        end
      end

      while true
        show_progress(".", progress_caret: true)
        break if threads.all? { |t| t.join(2) }
      end

      results = threads.filter_map(&:value)

      if results.blank?
        return { prompts: prompts, error: "Something went wrong, could not generate image" }
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
              upload: UploadCreator.new(file, "image.png").create_for(bot_user.id),
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

      { prompts: uploads.map { |item| item[:prompt] } }
    end
  end
end
