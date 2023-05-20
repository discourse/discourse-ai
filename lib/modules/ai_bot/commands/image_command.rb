#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class ImageCommand < Command
    class << self
      def name
        "image"
      end

      def desc
        "!image DESC - renders an image from the description (remove all connector words, keep it to 40 words or less)"
      end
    end

    def result_name
      "results"
    end

    def description_args
      { prompt: @last_prompt || 0 }
    end

    def custom_raw
      @last_custom_raw
    end

    def chain_next_response
      false
    end

    def process(prompt)
      @last_prompt = prompt
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

      @last_custom_raw =
        uploads
          .map { |upload| "![#{prompt.gsub(/\|\'\"/, "")}|512x512, 50%](#{upload.short_url})" }
          .join("\n\n")
    end
  end
end
