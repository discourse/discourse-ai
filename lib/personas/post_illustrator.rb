# frozen_string_literal: true

module DiscourseAi
  module Personas
    class PostIllustrator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
          You'll find the post between <input></input> XML tags.
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end
    end
  end
end
