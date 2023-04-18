# frozen_string_literal: true

module DiscourseAi
  class Tokenizer
    def self.tokenizer
      @@tokenizer ||= Tokenizers.from_file("./plugins/discourse-ai/tokenizers/bert-base-uncased.json")
    end

    def self.size(text)
      tokenizer.encode(text).tokens.size
    end
  end
end
