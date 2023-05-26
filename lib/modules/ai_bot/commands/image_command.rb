#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class ImageCommand < Command
    class << self
      def name
        "image"
      end

      def desc
        "!image DESC - renders an image from the description (remove all connector words, keep it to 40 words or less, be creative)"
      end
    end

    def result_name
      "results"
    end

    def description_args
      { prompt: @args || 0 }
    end

    def chain_next_response
      false
    end

    def post_raw_details
      "#{super}\n\n#{@last_custom_raw}"
    end

    def process
      prompt = @args

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
          .join(" ")

      nil
    end
  end
end
