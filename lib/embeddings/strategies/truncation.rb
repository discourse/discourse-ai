# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module Strategies
      class Truncation
        def id
          1
        end

        def version
          1
        end

        def prepare_text_from(target, tokenizer, max_length)
          case target
          when Topic
            topic_truncation(target, tokenizer, max_length)
          when Post
            post_truncation(target, tokenizer, max_length)
          when RagDocumentFragment
            tokenizer.truncate(target.fragment, max_length)
          else
            raise ArgumentError, "Invalid target type"
          end
        end

        private

        def topic_information(topic)
          info = +""

          if topic&.title.present?
            info << topic.title
            info << "\n\n"
          end
          if topic&.category&.name.present?
            info << topic.category.name
            info << "\n\n"
          end
          if SiteSetting.tagging_enabled && topic&.tags.present?
            info << topic.tags.pluck(:name).join(", ")
            info << "\n\n"
          end

          info
        end

        def topic_truncation(topic, tokenizer, max_length)
          text = +topic_information(topic)

          if topic&.topic_embed&.embed_content_cache&.present?
            text << Nokogiri::HTML5.fragment(topic.topic_embed.embed_content_cache).text
            text << "\n\n"
          end

          topic.posts.find_each do |post|
            text << Nokogiri::HTML5.fragment(post.cooked).text
            break if tokenizer.size(text) >= max_length #maybe keep a partial counter to speed this up?
            text << "\n\n"
          end

          tokenizer.truncate(text, max_length)
        end

        def post_truncation(post, tokenizer, max_length)
          text = +topic_information(post.topic)

          if post.is_first_post? && post.topic&.topic_embed&.embed_content_cache&.present?
            text << Nokogiri::HTML5.fragment(post.topic.topic_embed.embed_content_cache).text
          else
            text << Nokogiri::HTML5.fragment(post.cooked).text
          end

          tokenizer.truncate(text, max_length)
        end
      end
    end
  end
end
