#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class ImageCommand < Command
    class << self
      def name
        "image"
      end

      def desc
        "Renders an image from the description (remove all connector words, keep it to 40 words or less). Despite being a text based bot you can generate images!"
      end

      def parameters
        [
          Parameter.new(
            name: "prompt",
            description: "The prompt used to generate or create or draw the image",
            type: "string",
            required: true,
          ),
        ]
      end

      def custom_system_message
        <<~TEXT
          In Discourse the markdown (description|SIZE, ZOOM%)[upload://SOMETEXT] is used to denote images and uploads. NEVER try changing the to http or https links.
          ALWAYS prefer the upload:// format if available.
          When rendering multiple images place them in a [grid] ... [/grid] block
        TEXT
      end
    end

    def result_name
      "results"
    end

    def description_args
      { prompt: @last_prompt }
    end

    def chain_next_response
      true
    end

    def process(prompt)
      @last_prompt = prompt = JSON.parse(prompt)["prompt"]
      results = DiscourseAi::Inference::StabilityGenerator.perform!(prompt)

      uploads = []

      results[:artifacts].each_with_index do |image, i|
        f = Tempfile.new("v1_txt2img_#{i}.png")
        f.binmode
        f.write(Base64.decode64(image[:base64]))
        f.rewind
        uploads << UploadCreator.new(f, "image.png").create_for(bot_user.id)
        f.unlink
      end

      raw = <<~RAW
      [grid]
      #{
        uploads
          .map { |upload| "![#{prompt.gsub(/\|\'\"/, "")}|512x512, 50%](#{upload.short_url})" }
          .join(" ")
      }
      [/grid]
    RAW

      { prompt: prompt, markdown: raw, display_to_user: true }
    end
  end
end
