# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class TopicGist < Base
        def type
          AiSummary::GIST
        end

        def targets_data
          content = { content_title: target.title, contents: [] }

          op_post_number = 1

          last_twenty_posts =
            Post
              .where(topic_id: target.id)
              .where("post_type = ?", Post.types[:regular])
              .where("NOT hidden")
              .order("post_number DESC")
              .limit(20)
              .pluck(:post_number)

          posts_data =
            Post
              .where(topic_id: target.id)
              .joins(:user)
              .where("post_number IN (?)", last_twenty_posts << op_post_number)
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
            You are a summarization bot tasked with creating a single, concise sentence by merging disjoint summaries into a cohesive statement. 
            Your response should strictly be this single, comprehensive sentence, without any additional text or comments.
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
          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
            You are an advanced summarization bot. Your task is to analyze a given conversation and generate a single, 
            concise sentence that clearly conveys the main topic and purpose of the discussion to someone with no prior context. 

            - Focus on the central theme or issue being addressed, while maintaining an objective and neutral tone.
            - Avoid including extraneous details or subjective opinions.
            - Maintain the original language of the text being summarized.
          TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
            #{opts[:content_title].present? ? "The discussion title is: " + opts[:content_title] + ".\n" : ""}
            
            Here are the posts, inside <input></input> XML tags:

            <input>
              #{input}
            </input>

            Generate a single sentence of the text above maintaining the original language.
          TEXT

          prompt
        end
      end
    end
  end
end
