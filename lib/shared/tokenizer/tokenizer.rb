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

    class AllMpnetBaseV2Tokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/all-mpnet-base-v2.json")
      end
    end

    class Llama2Tokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/llama-2-70b-chat-hf.json")
      end
    end

    class MultilingualE5LargeTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/multilingual-e5-large.json")
      end
    end

    class OpenAiTokenizer < BasicTokenizer
      class << self
        def tokenizer
          @@tokenizer ||= Tiktoken.get_encoding("cl100k_base")
        end

        def tokenize(text)
          tokenizer.encode(text)
        end

        def truncate(text, max_length)
          # Fast track the common case where the text is already short enough.
          return text if text.size < max_length

          tokenizer.decode(tokenize(text).take(max_length))
        rescue Tiktoken::UnicodeError
          max_length = max_length - 1
          retry
        end

        def can_expand_tokens?(text, addition, max_length)
          return true if text.size + addition.size < max_length

          tokenizer.encode(text).length + tokenizer.encode(addition).length < max_length
        end
      end
    end
  end
end
