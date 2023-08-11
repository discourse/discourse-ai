# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class FoldContent < ::Summarization::Base
        def initialize(completion_model)
          @completion_model = completion_model
        end

        attr_reader :completion_model

        delegate :correctly_configured?,
                 :display_name,
                 :configuration_hint,
                 :model,
                 to: :completion_model

        def summarize(content, &on_partial_blk)
          opts = content.except(:contents)

          chunks = split_into_chunks(content[:contents])

          if chunks.length == 1
            {
              summary:
                completion_model.summarize_single(chunks.first[:summary], opts, &on_partial_blk),
              chunks: [],
            }
          else
            summaries = completion_model.summarize_in_chunks(chunks, opts)

            {
              summary: completion_model.concatenate_summaries(summaries, &on_partial_blk),
              chunks: summaries,
            }
          end
        end

        private

        def split_into_chunks(contents)
          section = { ids: [], summary: "" }

          chunks =
            contents.reduce([]) do |sections, item|
              new_content = completion_model.format_content_item(item)

              if completion_model.can_expand_tokens?(
                   section[:summary],
                   new_content,
                   completion_model.available_tokens,
                 )
                section[:summary] += new_content
                section[:ids] << item[:id]
              else
                sections << section
                section = { ids: [item[:id]], summary: new_content }
              end

              sections
            end

          chunks << section if section[:summary].present?

          chunks
        end
      end
    end
  end
end
