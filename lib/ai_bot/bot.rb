# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      BOT_NOT_FOUND = Class.new(StandardError)
      MAX_COMPLETIONS = 5

      def self.as(bot_user, persona: DiscourseAi::AiBot::Personas::General.new)
        new(bot_user, persona)
      end

      def initialize(bot_user, persona)
        @bot_user = bot_user
        @persona = persona
      end

      attr_reader :bot_user

      def get_updated_title(conversation_context, post_user)
        title_prompt = { insts: <<~TEXT, conversation_context: conversation_context }
          You are titlebot. Given a topic, you will figure out a title.
          You will never respond with anything but 7 word topic title.
        TEXT

        title_prompt[
          :input
        ] = "Based on our previous conversation, suggest a 7 word title without quoting any of it."

        DiscourseAi::Completions::Llm
          .proxy(model)
          .completion!(title_prompt, post_user)
          .strip
          .split("\n")
          .last
      end

      def reply(context, &update_blk)
        prompt = persona.craft_prompt(context)

        total_completions = 0
        ongoing_chain = true
        low_cost = false
        raw_context = []

        while total_completions <= MAX_COMPLETIONS && ongoing_chain
          current_model = model(prefer_low_cost: low_cost)
          llm = DiscourseAi::Completions::Llm.proxy(current_model)

          llm.completion!(prompt, context[:user]) do |partial, cancel|
            if (tool = persona.find_tool(partial))
              ongoing_chain = tool.chain_next_response?
              low_cost = tool.low_cost?
              tool_name = tool.class.name
              invocation_result_json = invoke_tool(tool, llm, cancel, &update_blk).to_json

              context = { type: "tool", name: tool_name, content: invocation_result_json }

              prompt[:conversation_context] ||= []

              if tool.standalone?
                prompt[:conversation_context] = [context]
              else
                prompt[:conversation_context] << context
              end

              raw_context << [invocation_result_json, tool_name, "function"]
            else
              ongoing_chain = false
              low_cost = false
              reply = update_blk.call(partial, cancel, nil)

              raw_context << [reply, bot_user.username]
            end

            total_completions += 1

            # do not allow tools when we are at the end of a chain (total_completions == MAX_COMPLETIONS)
            prompt.delete(:tools) if total_completions == MAX_COMPLETIONS
          end
        end

        raw_context
      end

      private

      attr_reader :persona

      def invoke_tool(tool, llm, cancel, &update_blk)
        update_blk.call("", cancel, build_placeholder(tool.summary))

        result =
          tool.invoke(bot_user, llm) do |progress|
            placeholder = build_placeholder(tool.summary, progress: progress)
            update_blk.call("", cancel, placeholder)
          end

        tool_details =
          build_placeholder(tool.summary, custom_raw: tool.custom_raw, details: tool.details)
        update_blk.call(tool_details, cancel, nil)

        result
      end

      def model(prefer_low_cost: false)
        default_model =
          case bot_user.id
          when DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID
            "claude-2"
          when DiscourseAi::AiBot::EntryPoint::GPT4_ID
            "gpt-4"
          when DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID
            "gpt-3.5-turbo"
          else
            nil
          end

        return "gpt-3.5-turbo-16k" if default_model == "gpt-4" && prefer_low_cost

        default_model
      end

      def tool_invocation?(partial)
        Nokogiri::HTML5.fragment(partial).at("invoke").present?
      end

      def build_placeholder(summary, custom_raw: nil, details: nil, progress: nil)
        +(<<~HTML).strip
        <details>
          <summary>#{summary}</summary>
          <p>#{details}</p>
        </details>
        #{progress}#{custom_raw}
        HTML
      end
    end
  end
end
