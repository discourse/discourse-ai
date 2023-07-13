# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Base
        def initialize(model, max_tokens:)
          @model = model
          @max_tokens = max_tokens
        end

        def correctly_configured?
          raise NotImplemented
        end

        def display_name
          raise NotImplemented
        end

        def configuration_hint
          raise NotImplemented
        end

        def summarize_in_chunks(chunks, opts)
          chunks.map do |chunk|
            chunk[:summary] = summarize_chunk(chunk[:summary], opts)
            chunk
          end
        end

        def concatenate_summaries(_summaries)
          raise NotImplemented
        end

        def summarize_with_truncation(_contents, _opts)
          raise NotImplemented
        end

        def summarize_single(chunk_text, opts)
          raise NotImplemented
        end

        def format_content_item(item)
          "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
        end

        def available_tokens
          max_tokens - reserved_tokens
        end

        attr_reader :model, :max_tokens

        protected

        def reserved_tokens
          # Reserve tokens for the response and the base prompt
          # ~500 words
          700
        end

        def summarize_chunk(_chunk_text, _opts)
          raise NotImplemented
        end

        def tokenizer
          raise NotImplemented
        end

        delegate :can_expand_tokens?, to: :tokenizer
      end
    end
  end
end
