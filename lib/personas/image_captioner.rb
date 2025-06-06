# frozen_string_literal: true

module DiscourseAi
  module Personas
    class ImageCaptioner < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        "You are a bot specializing in image captioning."
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end
    end
  end
end
