# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class HotTopicGists < Base
        def type
          AiSummary.summary_types[:gist]
        end

        def feature
          "gists"
        end

        def targets_data
          op_post_number = 1

          hot_topics_recent_cutoff = Time.zone.now - SiteSetting.hot_topics_recent_days.days

          recent_hot_posts =
            Post
              .where(topic_id: target.id)
              .where("post_type = ?", Post.types[:regular])
              .where("NOT hidden")
              .where("created_at >= ?", hot_topics_recent_cutoff)
              .pluck(:post_number)

          # It may happen that a topic is hot without any recent posts
          # In that case, we'll just grab the last 20 posts
          # for an useful summary of the current state of the topic
          if recent_hot_posts.empty?
            recent_hot_posts =
              Post
                .where(topic_id: target.id)
                .where("post_type = ?", Post.types[:regular])
                .where("NOT hidden")
                .order("post_number DESC")
                .limit(20)
                .pluck(:post_number)
          end
          posts_data =
            Post
              .where(topic_id: target.id)
              .joins(:user)
              .where("post_number IN (?)", recent_hot_posts << op_post_number)
              .order(:post_number)
              .pluck(:post_number, :raw, :username)

          posts_data.reduce([]) do |memo, (pn, raw, username)|
            raw_text = raw

            if pn == 1 && target.topic_embed&.embed_content_cache.present?
              raw_text = target.topic_embed&.embed_content_cache
            end

            memo << { poster: username, id: pn, text: raw_text }
          end
        end

        def summary_extension_prompt(summary, contents, _tokenizer)
          statements =
            contents
              .to_a
              .map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }
              .join("\n")

          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
            You are an advanced summarization bot. Your task is to update an existing single-sentence summary by integrating new developments from a conversation.
            Analyze the most recent messages to identify key updates or shifts in the main topic and reflect these in the updated summary.
            Emphasize new significant information or developments within the context of the initial conversation theme.

            ### Guidelines:

            - Ensure the revised summary remains concise and objective, maintaining a focus on the central theme or issue.
            - Omit extraneous details or subjective opinions.
            - Use the original language of the text.
            - Begin directly with the main topic or issue, avoiding introductory phrases.
            - Limit the updated summary to a maximum of 20 words.
            - Return the 20-word summary inside <ai></ai> tags.

          TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
            ### Context:

            This is the existing single-sentence summary:

            #{summary}

            And these are the new developments in the conversation:

            #{statements}

            Your task is to update an existing single-sentence summary by integrating new developments from a conversation.
            Return the 20-word summary inside <ai></ai> tags.
          TEXT

          prompt
        end

        def first_summary_prompt(contents, tokenizer)
          content_title = target.title
          statements =
            contents.to_a.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }

          op_statement = statements.shift.to_s
          split_1, split_2 =
            [op_statement[0, op_statement.size / 2], op_statement[(op_statement.size / 2)..-1]]

          truncation_length = 500

          op_statement = [
            tokenizer.truncate(split_1, truncation_length),
            tokenizer.truncate(split_2.reverse, truncation_length).reverse,
          ].join(" ")

          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
            You are an advanced summarization bot. Analyze a given conversation and produce a concise,
            single-sentence summary that conveys the main topic and current developments to someone with no prior context.

            ### Guidelines:

            - Emphasize the most recent updates while considering their significance within the original post.
            - Focus on the central theme or issue being addressed, maintaining an objective and neutral tone.
            - Exclude extraneous details or subjective opinions.
            - Use the original language of the text.
            - Begin directly with the main topic or issue, avoiding introductory phrases.
            - Limit the summary to a maximum of 20 words.
            - Do *NOT* repeat the discussion title in the summary.

            Return the summary inside <ai></ai> tags.\n
          TEXT

          context = +<<~TEXT
            ### Context:

            #{content_title.present? ? "The discussion title is: " + content_title + ". (DO NOT REPEAT THIS IN THE SUMMARY)\n" : ""}
            
            The conversation began with the following statement:
        
            #{op_statement}\n
          TEXT

          if statements.present?
            context << <<~TEXT
              Subsequent discussion includes the following:

              #{statements.join("\n")}

              Your task is to focus on these latest messages, capturing their meaning in the context of the initial statement.
            TEXT
          else
            context << "Your task is to capture the meaning of the initial statement."
          end

          prompt.push(type: :user, content: <<~TEXT.strip)
            #{context} Return the 20-word summary inside <ai></ai> tags.
          TEXT

          prompt
        end
      end
    end
  end
end
