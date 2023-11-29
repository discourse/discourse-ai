# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class Llama2Tokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/llama-2-70b-chat-hf.json")
      end
    end
  end
end
