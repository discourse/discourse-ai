# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class TopicSummary < Base
        def type
          AiSummary.summary_types[:complete]
        end

        def targets_data
          content = {
            resource_path: "#{Discourse.base_path}/t/-/#{target.id}",
            content_title: target.title,
            contents: [],
          }

          posts_data =
            (target.has_summary? ? best_replies : pick_selection).pluck(
              :post_number,
              :raw,
              :username,
            )

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
            You are a summarization bot that effectively concatenates disjointed summaries, creating a cohesive narrative.
            The narrative you create is in the form of one or multiple paragraphs.
            Your reply MUST BE a single concatenated summary using the summaries I'll provide to you.
            I'm NOT interested in anything other than the concatenated summary, don't include additional text or comments.
            You understand and generate Discourse forum Markdown.
            You format the response, including links, using Markdown.
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
          insts = +<<~TEXT
          You are an advanced summarization bot that generates concise, coherent summaries of provided text.

          - Only include the summary, without any additional commentary.
          - You understand and generate Discourse forum Markdown; including links, _italics_, **bold**.
          - Maintain the original language of the text being summarized.
          - Aim for summaries to be 400 words or less.

        TEXT

          insts << <<~TEXT if opts[:resource_path]
              - Each post is formatted as "<POST_NUMBER>) <USERNAME> <MESSAGE>"
              - Cite specific noteworthy posts using the format [NAME](#{opts[:resource_path]}/POST_NUMBER)
                - Example: link to the 3rd post by sam: [sam](#{opts[:resource_path]}/3)
                - Example: link to the 6th post by jane: [agreed with](#{opts[:resource_path]}/6)
                - Example: link to the 13th post by joe: [#13](#{opts[:resource_path]}/13)
              - When formatting usernames either use @USERNMAE OR [USERNAME](#{opts[:resource_path]}/POST_NUMBER)
            TEXT

          prompt = DiscourseAi::Completions::Prompt.new(insts.strip)

          if opts[:resource_path]
            prompt.push(
              type: :user,
              content:
                "Here are the posts inside <input></input> XML tags:\n\n<input>1) user1 said: I love Mondays 2) user2 said: I hate Mondays</input>\n\nGenerate a concise, coherent summary of the text above maintaining the original language.",
            )
            prompt.push(
              type: :model,
              content:
                "Two users are sharing their feelings toward Mondays. [user1](#{opts[:resource_path]}/1) hates them, while [user2](#{opts[:resource_path]}/2) loves them.",
            )
          end

          prompt.push(type: :user, content: <<~TEXT.strip)
        #{opts[:content_title].present? ? "The discussion title is: " + opts[:content_title] + ".\n" : ""}
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
