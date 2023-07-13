# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module Strategies
      class Truncation
        attr_reader :processed_target, :digest

        def self.id
          1
        end

        def id
          self.class.id
        end

        def version
          1
        end

        def initialize(target, model)
          @model = model
          @target = target
          @tokenizer = @model.tokenizer
          @max_length = @model.max_sequence_length
          @processed_target = +""
        end

        # Need a better name for this method
        def process!
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
          t = @processed_target

          t << topic.title
          t << "\n\n"
          t << topic.category.name
          if SiteSetting.tagging_enabled
            t << "\n\n"
            t << topic.tags.pluck(:name).join(", ")
          end
          t << "\n\n"

          topic.posts.find_each do |post|
            t << post.raw
            break if @tokenizer.size(t) >= @max_length
            t << "\n\n"
          end

          @tokenizer.truncate(t, @max_length)
        end

        def post_truncation(post)
          t = processed_target

          t << post.topic.title
          t << "\n\n"
          t << post.topic.category.name
          if SiteSetting.tagging_enabled
            t << "\n\n"
            t << post.topic.tags.pluck(:name).join(", ")
          end
          t << "\n\n"
          t << post.raw

          @tokenizer.truncate(t, @max_length)
        end
      end
    end
  end
end
