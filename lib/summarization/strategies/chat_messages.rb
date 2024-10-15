# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class ChatMessages < Base
        def type
          AiSummary.summary_types[:complete]
        end

        def initialize(target, since)
          super(target)
          @since = since
        end

        def targets_data
          content = { content_title: target.name }

          content[:contents] = target
            .chat_messages
            .where("chat_messages.created_at > ?", since.hours.ago)
            .includes(:user)
            .order(created_at: :asc)
            .pluck(:id, :username_lower, :message)
            .map { { id: _1, poster: _2, text: _3 } }

          content
        end

        def contatenation_prompt(texts_to_summarize)
          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
          You are a summarization bot tasked with creating a cohesive narrative by intelligently merging multiple disjointed summaries. 
          Your response should consist of well-structured paragraphs that combines these summaries into a clear and comprehensive overview. 
          Avoid adding any additional text or commentary. Format your output using Discourse forum Markdown.
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
            You are a summarization bot designed to generate clear and insightful paragraphs that conveys the main topics 
            and developments from a series of chat messages within a user-selected time window. 
            
            Analyze the messages to extract key themes, participants' intentions, and any significant conclusions or decisions. 
            Your summary should be concise yet comprehensive, providing an overview that is accessible to someone with no prior context of the conversation. 

            - Only include the summary, without any additional commentary.
            - You understand and generate Discourse forum Markdown; including links, _italics_, **bold**.
            - Maintain the original language of the text being summarized.
            - Aim for summaries to be 400 words or less.

          TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
            #{opts[:content_title].present? ? "The name of the channel is: " + opts[:content_title] + ".\n" : ""}
            
            Here are the messages, inside <input></input> XML tags:

            <input>
              #{input}
            </input>

            Generate a summary of the given chat messages.
          TEXT

          prompt
        end

        private

        attr_reader :since
      end
    end
  end
end
