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
          .generate(title_prompt, user: post_user)
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
          tool_found = false

          result =
            llm.generate(prompt, user: context[:user]) do |partial, cancel|
              if (tool = persona.find_tool(partial))
                tool_found = true
                ongoing_chain = tool.chain_next_response?
                low_cost = tool.low_cost?
                tool_call_id = tool.tool_call_id
                invocation_result_json = invoke_tool(tool, llm, cancel, &update_blk).to_json

                tool_call_message = {
                  type: :tool_call,
                  id: tool_call_id,
                  content: { name: tool.name, arguments: tool.parameters }.to_json,
                }

                tool_message = { type: :tool, id: tool_call_id, content: invocation_result_json }

                if tool.standalone?
                  standalone_conext =
                    context.dup.merge(
                      conversation_context: [
                        context[:conversation_context].last,
                        tool_call_message,
                        tool_message,
                      ],
                    )
                  prompt = persona.craft_prompt(standalone_conext)
                else
                  prompt.push(**tool_call_message)
                  prompt.push(**tool_message)
                end

                raw_context << [tool_call_message[:content], tool_call_id, "tool_call"]
                raw_context << [invocation_result_json, tool_call_id, "tool"]
              else
                update_blk.call(partial, cancel, nil)
              end
            end

          if !tool_found
            ongoing_chain = false
            raw_context << [result, bot_user.username]
          end
          total_completions += 1

          # do not allow tools when we are at the end of a chain (total_completions == MAX_COMPLETIONS)
          prompt.tools = [] if total_completions == MAX_COMPLETIONS
        end

        raw_context
      end

      attr_reader :persona

      private

      def invoke_tool(tool, llm, cancel, &update_blk)
        update_blk.call("", cancel, build_placeholder(tool.summary, ""))

        result =
          tool.invoke(bot_user, llm) do |progress|
            placeholder = build_placeholder(tool.summary, progress)
            update_blk.call("", cancel, placeholder)
          end

        tool_details = build_placeholder(tool.summary, tool.details, custom_raw: tool.custom_raw)
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
          when DiscourseAi::AiBot::EntryPoint::GPT4_TURBO_ID
            "gpt-4-turbo"
          when DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID
            "gpt-3.5-turbo-16k"
          when DiscourseAi::AiBot::EntryPoint::MIXTRAL_ID
            "mistralai/Mixtral-8x7B-Instruct-v0.1"
          when DiscourseAi::AiBot::EntryPoint::GEMINI_ID
            "gemini-pro"
          when DiscourseAi::AiBot::EntryPoint::FAKE_ID
            "fake"
          else
            nil
          end

        if %w[gpt-4 gpt-4-turbo].include?(default_model) && prefer_low_cost
          return "gpt-3.5-turbo-16k"
        end

        default_model
      end

      def tool_invocation?(partial)
        Nokogiri::HTML5.fragment(partial).at("invoke").present?
      end

      def build_placeholder(summary, details, custom_raw: nil)
        placeholder = +(<<~HTML)
        <details>
          <summary>#{summary}</summary>
          <p>#{details}</p>
        </details>
        HTML

        if custom_raw
          placeholder << "\n"
          placeholder << custom_raw
        else
          # we need this for cursor placeholder to work
          # doing this in CSS is very hard
          # if changing test with a custom tool such as search
          placeholder << "<span></span>\n\n"
        end

        placeholder
      end
    end
  end
end
