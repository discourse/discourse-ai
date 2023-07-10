# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module Strategies
      class Truncation
        def self.id
          1
        end

        def id
          self.class.id
        end

        def initialize(target, model)
          @model = model
          @target = target
          @tokenizer = @model.tokenizer
          @max_length = @model.max_sequence_length
        end

        # Need a better name for this method
        def process!
          @processed_target =
            case @target
            when Topic
              topic_truncation(@target)
            when Post
              post_truncation(@target)
            else
              raise ArgumentError, "Invalid target type"
            end

          @digest = OpenSSL::Digest::SHA1.hexdigest(@processed_target)
        end

        def topic_truncation(topic)
          result = +""

          restult << topic.title
          result << "\n\n"
          result << topic.category.name
          if SiteSetting.tagging_enabled
            result << "\n\n"
            result << topic.tags.pluck(:name).join(", ")
          end
          result << "\n\n"

          topic.posts.each do |post|
            result << post.raw
            break if @tokenizer.size(result) >= @max_length
            result << "\n\n"
          end

          @tokenizer.truncate(result, @max_length)
        end

        def post_truncation(post)
          result = +""

          result << post.topic.title
          result << "\n\n"
          result << post.topic.category.name
          if SiteSetting.tagging_enabled
            result << "\n\n"
            result << post.topic.tags.pluck(:name).join(", ")
          end
          result << "\n\n"
          result << post.raw

          @tokenizer.truncate(result, @max_length)
        end
      end
    end
  end
end
