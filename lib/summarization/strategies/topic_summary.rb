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
          posts_data =
            (target.has_summary? ? best_replies : pick_selection).pluck(
              :post_number,
              :raw,
              :username,
              :last_version_at,
            )

          posts_data.reduce([]) do |memo, (pn, raw, username, last_version_at)|
            raw_text = raw

            if pn == 1 && target.topic_embed&.embed_content_cache.present?
              raw_text = target.topic_embed&.embed_content_cache
            end

            memo << { poster: username, id: pn, text: raw_text, last_version_at: last_version_at }
          end
        end

        def summary_extension_prompt(summary, contents)
          resource_path = "#{Discourse.base_path}/t/-/#{target.id}"
          content_title = target.title
          input =
            contents.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]})" }.join

          if SiteSetting.ai_summary_consolidator_persona_id
            prompt =
              DiscourseAi::Completions::Prompt.new(
                AiPersona.find_by(id: SiteSetting.ai_summary_consolidator_persona_id).system_prompt,
                topic_id: target.id,
              )
          else
            prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT, topic_id: target.id) # summary extension prompt
              You are an advanced summarization bot tasked with enhancing an existing summary by incorporating additional posts.

              ### Guidelines:
              - Only include the enhanced summary, without any additional commentary.
              - Understand and generate Discourse forum Markdown; including links, _italics_, **bold**.
              - Maintain the original language of the text being summarized.
              - Aim for summaries to be 400 words or less.
              - Each new post is formatted as "<POST_NUMBER>) <USERNAME> <MESSAGE>"
              - Cite specific noteworthy posts using the format [DESCRIPTION](#{resource_path}/POST_NUMBER)
                - Example: links to the 3rd and 6th posts by sam: sam ([#3](#{resource_path}/3), [#6](#{resource_path}/6))
                - Example: link to the 6th post by jane: [agreed with](#{resource_path}/6)
                - Example: link to the 13th post by joe: [joe](#{resource_path}/13)
              - When formatting usernames either use @USERNAME or [USERNAME](#{resource_path}/POST_NUMBER)
            TEXT
          end

          prompt.push(type: :user, content: <<~TEXT.strip)
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

          prompt
        end

        def first_summary_prompt(contents)
          resource_path = "#{Discourse.base_path}/t/-/#{target.id}"
          content_title = target.title
          input =
            contents.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }.join

          if SiteSetting.ai_summary_persona_id.present?
            prompt =
              DiscourseAi::Completions::Prompt.new(
                AiPersona.find_by(id: SiteSetting.ai_summary_consolidator_persona_id).system_prompt,
                topic_id: target.id,
              )
          else
            prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip, topic_id: target.id)
              You are an advanced summarization bot that generates concise, coherent summaries of provided text.

              - Only include the summary, without any additional commentary.
              - You understand and generate Discourse forum Markdown; including links, _italics_, **bold**.
              - Maintain the original language of the text being summarized.
              - Aim for summaries to be 400 words or less.
              - Each post is formatted as "<POST_NUMBER>) <USERNAME> <MESSAGE>"
              - Cite specific noteworthy posts using the format [DESCRIPTION](#{resource_path}/POST_NUMBER)
                - Example: links to the 3rd and 6th posts by sam: sam ([#3](#{resource_path}/3), [#6](#{resource_path}/6))
                - Example: link to the 6th post by jane: [agreed with](#{resource_path}/6)
                - Example: link to the 13th post by joe: [joe](#{resource_path}/13)
              - When formatting usernames either use @USERNMAE OR [USERNAME](#{resource_path}/POST_NUMBER)
            TEXT
          end

          prompt.push(
            type: :user,
            content:
              "Here are the posts inside <input></input> XML tags:\n\n<input>1) user1 said: I love Mondays 2) user2 said: I hate Mondays</input>\n\nGenerate a concise, coherent summary of the text above maintaining the original language.",
          )
          prompt.push(
            type: :model,
            content:
              "Two users are sharing their feelings toward Mondays. [user1](#{resource_path}/1) hates them, while [user2](#{resource_path}/2) loves them.",
          )

          prompt.push(type: :user, content: <<~TEXT.strip)
            #{content_title.present? ? "The discussion title is: " + content_title + ".\n" : ""}
            Here are the posts, inside <input></input> XML tags:

            <input>
              #{input}
            </input>

            Generate a concise, coherent summary of the text above maintaining the original language.
          TEXT

          prompt
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
