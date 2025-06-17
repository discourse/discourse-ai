# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class QwenTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||= Tokenizers.from_file("./plugins/discourse-ai/tokenizers/qwen3.json")
      end
    end
  end
end
