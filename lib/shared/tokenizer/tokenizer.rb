# frozen_string_literal: true

module DiscourseAi
  class Tokenizer
    def self.tokenizer
      @@tokenizer ||=
        Tokenizers.from_file("./plugins/discourse-ai/tokenizers/bert-base-uncased.json")
    end

    def self.tokenize(text)
      tokenizer.encode(text).tokens
    end
    def self.size(text)
      tokenize(text).size
    end
  end
end
