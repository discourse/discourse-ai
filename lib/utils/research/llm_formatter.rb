# frozen_string_literal: true

module DiscourseAi
  module Utils
    module Research
      class LlmFormatter
        def initialize(filter, max_tokens_per_batch:, tokenizer:)
          @filter = filter
          @max_tokens_per_batch = max_tokens_per_batch
          @tokenizer = tokenizer
          @to_process = filter_to_hash
        end

        def next_batch
          # return text that is easily consumed by the LLM containing:
          # - topic title, tags, category and creation date
          # - info about previous posts in the topic that are omitted (mostly count eg: 7 posts omitted)
          # - raw post content
          # - author name
          # - date
          # - info about future posts in the topic that are omitted
          #
          # always attempt to return entire topics (or multiple) if possible
          # return nil if we are done
          #
          # example_return:
          # { post_count: 12, topic_count: 3, text: "..." }
        end

        private

        def filter_to_hash
          hash = {}
          filter
            .search
            .pluck(:topic_id, :post_id, :post_number)
            .each do |topic_id, post_id, post_number|
              hash[topic_id] ||= { posts: [] }
              hash[topic_id][:posts] << [post_id, post_number]
            end

          hash.each_value { |topic| topic[:posts].sort_by! { |_, post_number| post_number } }
          hash
        end
      end
    end
  end
end
