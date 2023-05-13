# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class BasicTokenizer
      def self.tokenizer
        raise NotImplementedError
      end

      def self.tokenize(text)
        tokenizer.encode(text).tokens
      end
      def self.size(text)
        tokenize(text).size
      end
      def self.truncate(text, max_length)
        tokenizer.decode(tokenizer.encode(text).ids.take(max_length))
      end
    end

    class BertTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/bert-base-uncased.json")
      end
    end

    class AnthropicTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/claude-v1-tokenization.json")
      end
    end

    class OpenAiTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||= Tiktoken.get_encoding("cl100k_base")
      end

      def self.tokenize(text)
        tokenizer.encode(text)
      end

      def self.truncate(text, max_length)
        tokenizer.decode(tokenize(text).take(max_length))
      end
    end
  end
end
