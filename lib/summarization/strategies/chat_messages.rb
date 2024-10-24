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
          target
            .chat_messages
            .where("chat_messages.created_at > ?", since.hours.ago)
            .includes(:user)
            .order(created_at: :asc)
            .pluck(:id, :username_lower, :message)
            .map { { id: _1, poster: _2, text: _3 } }
        end

        def summary_extension_prompt(summary, contents)
          input =
            contents
              .map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }
              .join("\n")

          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
            You are a summarization bot tasked with expanding on an existing summary by incorporating new chat messages.
            Your goal is to seamlessly integrate the additional information into the existing summary, preserving the clarity and insights of the original while reflecting any new developments, themes, or conclusions.
            Analyze the new messages to identify key themes, participants' intentions, and any significant decisions or resolutions.
            Update the summary to include these aspects in a way that remains concise, comprehensive, and accessible to someone with no prior context of the conversation.

            ### Guidelines:

            - Merge the new information naturally with the existing summary without redundancy.
            - Only include the updated summary, WITHOUT additional commentary.
            - Don't mention the channel title. Avoid extraneous details or subjective opinions.
            - Maintain the original language of the text being summarized.
            - The same user could write multiple messages in a row, don't treat them as different persons.
            - Aim for summaries to be extended by a reasonable amount, but strive to maintain a total length of 400 words or less, unless absolutely necessary for comprehensiveness.

        TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
          ### Context:

          This is the existing summary:

          #{summary}

          These are the new chat messages:

          #{input}

          Intengrate the new messages into the existing summary.
        TEXT

          prompt
        end

        def first_summary_prompt(contents)
          content_title = target.name
          input =
            contents.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }.join

          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
            You are a summarization bot designed to generate clear and insightful paragraphs that conveys the main topics 
            and developments from a series of chat messages within a user-selected time window. 
            
            Analyze the messages to extract key themes, participants' intentions, and any significant conclusions or decisions. 
            Your summary should be concise yet comprehensive, providing an overview that is accessible to someone with no prior context of the conversation. 

            - Only include the summary, WITHOUT additional commentary.
            - Don't mention the channel title. Avoid including extraneous details or subjective opinions.
            - Maintain the original language of the text being summarized.
            - The same user could write multiple messages in a row, don't treat them as different persons.
            - Aim for summaries to be 400 words or less.

          TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
            #{content_title.present? ? "The name of the channel is: " + content_title + ".\n" : ""}
            
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
