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

        def summarize_in_chunks(contents, opts)
          chunks = []

          section = { ids: [], summary: "" }

          contents.each do |item|
            new_content = format_content_item(item)

            if tokenizer.can_expand_tokens?(
                 section[:summary],
                 new_content,
                 max_tokens - reserved_tokens,
               )
              section[:summary] += new_content
              section[:ids] << item[:id]
            else
              chunks << section
              section = { ids: [item[:id]], summary: new_content }
            end
          end

          chunks << section if section[:summary].present?

          chunks.each { |chunk| chunk[:summary] = summarize_chunk(chunk[:summary], opts) }

          chunks
        end

        def concatenate_summaries(_summaries)
          raise NotImplemented
        end

        def summarize_with_truncation(_contents, _opts)
          raise NotImplemented
        end

        attr_reader :model

        protected

        attr_reader :max_tokens

        def summarize_chunk(_chunk_text, _opts)
          raise NotImplemented
        end

        def format_content_item(item)
          "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
        end

        def reserved_tokens
          # Reserve tokens for the response and the base prompt
          # ~500 words
          700
        end
      end
    end
  end
end
