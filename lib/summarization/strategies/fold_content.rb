# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class FoldContent < DiscourseAi::Summarization::Models::Base
        def initialize(completion_model)
          @completion_model = completion_model
        end

        attr_reader :completion_model

        delegate :correctly_configured?,
                 :display_name,
                 :configuration_hint,
                 :model,
                 to: :completion_model

        def summarize(content, user, &on_partial_blk)
          opts = content.except(:contents)

          llm = DiscourseAi::Completions::Llm.proxy(completion_model.model_name)

          summary_content =
            content[:contents].map { |c| { ids: [c[:id]], summary: format_content_item(c) } }

          {
            summary:
              summarize_single(llm, summary_content.first[:summary], user, opts, &on_partial_blk),
          }
        end

        private

        def format_content_item(item)
          "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
        end

        def summarize_single(llm, text, user, opts, &on_partial_blk)
          prompt = summarization_prompt(text, opts)

          llm.generate(prompt, user: user, feature_name: "summarize", &on_partial_blk)
        end

        def summarization_prompt(input, opts)
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
      end
    end
  end
end
