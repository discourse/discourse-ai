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

        def decode(token_ids)
          tokenizer.decode(token_ids)
        end

        def encode(tokens)
          tokenizer.encode(tokens).ids
        end

        def truncate(text, max_length)
          # fast track common case, /2 to handle unicode chars
          # than can take more than 1 token per char
          return text if !SiteSetting.ai_strict_token_counting && text.size < max_length / 2
          tokenizer.decode(tokenizer.encode(text).ids.take(max_length))
        end

        def can_expand_tokens?(text, addition, max_length)
          # fast track common case, /2 to handle unicode chars
          # than can take more than 1 token per char
          if !SiteSetting.ai_strict_token_counting && text.size + addition.size < max_length / 2
            return true
          end

          tokenizer.encode(text).ids.length + tokenizer.encode(addition).ids.length < max_length
        end
      end
    end
  end
end
