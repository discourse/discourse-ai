# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class BasicTokenizer
      class << self
        def tokenizer
          raise NotImplementedError
        end

        def tokenize(text)
          tokenizer.encode(text).tokens
        end

        def size(text)
          tokenize(text).size
        end

        def truncate(text, max_length)
          # Fast track the common case where the text is already short enough.
          return text if text.size < max_length

          tokenizer.decode(tokenizer.encode(text).ids.take(max_length))
        end

        def can_expand_tokens?(text, addition, max_length)
          return true if text.size + addition.size < max_length

          tokenizer.encode(text).ids.length + tokenizer.encode(addition).ids.length < max_length
        end
      end
    end
  end
end
