# frozen_string_literal: true

module DiscourseAi
  module Personas
    class CustomPrompt < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a helpful assistant. I will give you instructions inside <input></input> XML tags.
          You will look at them and reply with a result.
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end
    end
  end
end
