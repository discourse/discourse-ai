# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class HotTopicGists < Base
        def type
          AiSummary.summary_types[:gist]
        end

        def targets_data
          content = { content_title: target.title, contents: [] }

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

          posts_data.each do |(pn, raw, username)|
            raw_text = raw

            if pn == 1 && target.topic_embed&.embed_content_cache.present?
              raw_text = target.topic_embed&.embed_content_cache
            end

            content[:contents] << { poster: username, id: pn, text: raw_text }
          end

          content
        end

        def concatenation_prompt(texts_to_summarize)
          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
            You are a summarization bot tasked with creating a single, concise sentence by merging disjointed summaries into a cohesive statement. 
            Your response should strictly be this single, comprehensive sentence, without any additional text or comments.

            - Focus on the central theme or issue being addressed, maintaining an objective and neutral tone.
            - Exclude extraneous details or subjective opinions.
            - Use the original language of the text.
            - Begin directly with the main topic or issue, avoiding introductory phrases.
            - Limit the summary to a maximum of 20 words.
          TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
            THESE are the summaries, each one separated by a newline, all of them inside <input></input> XML tags:

            <input>
              #{texts_to_summarize.join("\n")}
            </input>
          TEXT

          prompt
        end

        def summarize_single_prompt(input, opts)
          statements = input.split(/(?=\d+\) \w+ said:)/)

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
          TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
            ### Context:
          
            The conversation began with the following statement:

            #{opts[:content_title].present? ? "The discussion title is: " + opts[:content_title] + ".\n" : ""}
        
            #{statements&.pop}
        
            Subsequent discussion includes the following:

            #{statements&.join}
                  
            Your task is to focus on these latest messages, capturing their meaning in the context of the initial post.
          TEXT

          prompt
        end
      end
    end
  end
end
