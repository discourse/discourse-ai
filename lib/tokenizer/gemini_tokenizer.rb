# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class GeminiTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||= Tokenizers.from_file("./plugins/discourse-ai/tokenizers/gemma3.json")
      end
    end
  end
end
