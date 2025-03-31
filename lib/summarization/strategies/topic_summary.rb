# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class TopicSummary < Base
        def type
          AiSummary.summary_types[:complete]
        end

        def highest_target_number
          target.highest_post_number
        end

        def targets_data
          post_attributes = %i[post_number raw username last_version_at]
          if SiteSetting.enable_names && !SiteSetting.prioritize_username_in_ux
            post_attributes.push(:name)
          end

          posts_data = (target.has_summary? ? best_replies : pick_selection).pluck(post_attributes)

          posts_data.reduce([]) do |memo, (pn, raw, username, last_version_at, name)|
            raw_text = raw

            if pn == 1 && target.topic_embed&.embed_content_cache.present?
              raw_text = target.topic_embed&.embed_content_cache
            end

            display_name = name.presence || username

            memo << {
              poster: display_name,
              id: pn,
              text: raw_text,
              last_version_at: last_version_at,
            }
          end
        end

        def summary_extension_messages(summary, contents)
          resource_path = "#{Discourse.base_path}/t/-/#{target.id}"
          content_title = target.title
          input =
            contents.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]})" }.join

          [{ type: :user, content: <<~TEXT.strip }]
            ### Context:

            #{content_title.present? ? "The discussion title is: " + content_title + ".\n" : ""}

            Here is the existing summary:

            #{summary}

            Here are the new posts, inside <input></input> XML tags:

            <input>
            #{input}
            </input>

            Integrate the new information to generate an enhanced concise and coherent summary.
          TEXT
        end

        def first_summary_messages(contents)
          resource_path = "#{Discourse.base_path}/t/-/#{target.id}"
          content_title = target.title
          input =
            contents.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }.join

          messages = []
          messages << {
            type: :user,
            content:
              "Here are the posts inside <input></input> XML tags:\n\n<input>1) user1 said: I love Mondays 2) user2 said: I hate Mondays</input>\n\nGenerate a concise, coherent summary of the text above maintaining the original language.",
          }

          messages << {
            type: :model,
            content:
              "Two users are sharing their feelings toward Mondays. [user1](#{resource_path}/1) hates them, while [user2](#{resource_path}/2) loves them.",
          }

          messages << { type: :user, content: <<~TEXT.strip }
            #{content_title.present? ? "The discussion title is: " + content_title + ".\n" : ""}
            Here are the posts, inside <input></input> XML tags:

            <input>
              #{input}
            </input>

            Generate a concise, coherent summary of the text above maintaining the original language.
          TEXT

          messages
        end

        private

        attr_reader :topic

        def best_replies
          Post
            .summary(target.id)
            .where("post_type = ?", Post.types[:regular])
            .where("NOT hidden")
            .joins(:user)
            .order(:post_number)
        end

        def pick_selection
          posts =
            Post
              .where(topic_id: target.id)
              .where("post_type = ?", Post.types[:regular])
              .where("NOT hidden")
              .order(:post_number)

          post_numbers = posts.limit(5).pluck(:post_number)
          post_numbers += posts.reorder("posts.score desc").limit(50).pluck(:post_number)
          post_numbers += posts.reorder("post_number desc").limit(5).pluck(:post_number)

          Post
            .where(topic_id: target.id)
            .joins(:user)
            .where("post_number in (?)", post_numbers)
            .order(:post_number)
        end
      end
    end
  end
end
