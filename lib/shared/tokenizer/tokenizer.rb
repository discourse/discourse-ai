# frozen_string_literal: true

module DiscourseAi
  class Tokenizer
    def self.tokenizer
      @@tokenizer ||= Tokenizers.from_pretrained("bert-base-uncased")
    end

    def self.size(text)
      tokenizer.encode(text).tokens.size
    end
  end
end
