# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class MxbaiEmbedXsmallV1Tokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/mxbai-embed-xsmall-v1.json")
      end
    end
  end
end
