# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class OpenAiTokenizer < BasicTokenizer
      class << self
        def tokenizer
          @@tokenizer ||= Tiktoken.get_encoding("cl100k_base")
        end

        def tokenize(text)
          tokenizer.encode(text)
        end

        def truncate(text, max_length)
          tokenizer.decode(tokenize(text).take(max_length))
        rescue Tiktoken::UnicodeError
          max_length = max_length - 1
          retry
        end

        def can_expand_tokens?(text, addition, max_length)
          tokenizer.encode(text).length + tokenizer.encode(addition).length < max_length
        end
      end
    end
  end
end
