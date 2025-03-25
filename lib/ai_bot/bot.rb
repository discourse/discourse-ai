# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      attr_reader :model

      BOT_NOT_FOUND = Class.new(StandardError)

      # the future is agentic, allow for more turns
      MAX_COMPLETIONS = 8

      # limit is arbitrary, but 5 which was used in the past was too low
      MAX_TOOLS = 20

      def self.as(bot_user, persona: DiscourseAi::AiBot::Personas::General.new, model: nil)
        new(bot_user, persona, model)
      end

      def initialize(bot_user, persona, model = nil)
        @bot_user = bot_user
        @persona = persona
        @model =
          model || self.class.guess_model(bot_user) || LlmModel.find(@persona.class.default_llm_id)
      end

      attr_reader :bot_user
      attr_accessor :persona

      def get_updated_title(conversation_context, post, user)
        system_insts = <<~TEXT.strip
        You are titlebot. Given a conversation, you will suggest a title.

        - You will never respond with anything but the suggested title.
        - You will always match the conversation language in your title suggestion.
        - Title will capture the essence of the conversation.
        TEXT

        # conversation context may contain tool calls, and confusing user names
        # clean it up
        conversation = +""
        conversation_context.each do |context|
          if context[:type] == :user
            conversation << "User said:\n#{context[:content]}\n\n"
          elsif context[:type] == :model
            conversation << "Model said:\n#{context[:content]}\n\n"
          end
        end

        instruction = <<~TEXT.strip
        Given the following conversation:

        {{{
        #{conversation}
        }}}

        Reply only with a title that is 7 words or less.
        TEXT

        title_prompt =
          DiscourseAi::Completions::Prompt.new(
            system_insts,
            messages: [type: :user, content: instruction],
            topic_id: post.topic_id,
          )

        DiscourseAi::Completions::Llm
          .proxy(model)
          .generate(title_prompt, user: user, feature_name: "bot_title")
          .strip
          .split("\n")
          .last
      end

      def force_tool_if_needed(prompt, context)
        return if prompt.tool_choice == :none

        context.chosen_tools ||= []
        forced_tools = persona.force_tool_use.map { |tool| tool.name }
        force_tool = forced_tools.find { |name| !context.chosen_tools.include?(name) }

        if force_tool && persona.forced_tool_count > 0
          user_turns = prompt.messages.select { |m| m[:type] == :user }.length
          force_tool = false if user_turns > persona.forced_tool_count
        end

        if force_tool
          context.chosen_tools << force_tool
          prompt.tool_choice = force_tool
        else
          prompt.tool_choice = nil
        end
      end

      def reply(context, &update_blk)
        llm = DiscourseAi::Completions::Llm.proxy(model)
        prompt = persona.craft_prompt(context, llm: llm)

        total_completions = 0
        ongoing_chain = true
        raw_context = []

        user = context.user

        llm_kwargs = { user: user }
        llm_kwargs[:temperature] = persona.temperature if persona.temperature
        llm_kwargs[:top_p] = persona.top_p if persona.top_p

        needs_newlines = false
        tools_ran = 0

        while total_completions < MAX_COMPLETIONS && ongoing_chain
          tool_found = false
          force_tool_if_needed(prompt, context)

          tool_halted = false

          allow_partial_tool_calls = persona.allow_partial_tool_calls?
          existing_tools = Set.new
          current_thinking = []

          result =
            llm.generate(
              prompt,
              feature_name: "bot",
              partial_tool_calls: allow_partial_tool_calls,
              output_thinking: true,
              **llm_kwargs,
            ) do |partial, cancel|
              tool =
                persona.find_tool(
                  partial,
                  bot_user: user,
                  llm: llm,
                  context: context,
                  existing_tools: existing_tools,
                )
              tool = nil if tools_ran >= MAX_TOOLS

              if tool.present?
                existing_tools << tool
                tool_call = partial
                if tool_call.partial?
                  if tool.class.allow_partial_tool_calls?
                    tool.partial_invoke
                    update_blk.call("", cancel, tool.custom_raw, :partial_tool)
                  end
                  next
                end

                tool_found = true
                # a bit hacky, but extra newlines do no harm
                if needs_newlines
                  update_blk.call("\n\n", cancel)
                  needs_newlines = false
                end

                process_tool(
                  tool: tool,
                  raw_context: raw_context,
                  llm: llm,
                  cancel: cancel,
                  update_blk: update_blk,
                  prompt: prompt,
                  context: context,
                  current_thinking: current_thinking,
                )

                tools_ran += 1
                ongoing_chain &&= tool.chain_next_response?

                tool_halted = true if !tool.chain_next_response?
              else
                next if tool_halted
                needs_newlines = true
                if partial.is_a?(DiscourseAi::Completions::ToolCall)
                  Rails.logger.warn("DiscourseAi: Tool not found: #{partial.name}")
                else
                  if partial.is_a?(DiscourseAi::Completions::Thinking)
                    if partial.partial? && partial.message.present?
                      update_blk.call(partial.message, cancel, nil, :thinking)
                    end
                    if !partial.partial?
                      # this will be dealt with later
                      raw_context << partial
                      current_thinking << partial
                    end
                  else
                    update_blk.call(partial, cancel)
                  end
                end
              end
            end

          if !tool_found
            ongoing_chain = false
            text = result

            # we must strip out thinking and other types of blocks
            if result.is_a?(Array)
              text = +""
              result.each { |item| text << item if item.is_a?(String) }
            end
            raw_context << [text, bot_user.username]
          end

          total_completions += 1

          # do not allow tools when we are at the end of a chain (total_completions == MAX_COMPLETIONS - 1)
          prompt.tool_choice = :none if total_completions == MAX_COMPLETIONS - 1
        end

        embed_thinking(raw_context)
      end

      private

      def embed_thinking(raw_context)
        embedded_thinking = []
        thinking_info = nil
        raw_context.each do |context|
          if context.is_a?(DiscourseAi::Completions::Thinking)
            thinking_info ||= {}
            if context.redacted
              thinking_info[:redacted_thinking_signature] = context.signature
            else
              thinking_info[:thinking] = context.message
              thinking_info[:thinking_signature] = context.signature
            end
          else
            if thinking_info
              context = context.dup
              context[4] = thinking_info
            end
            embedded_thinking << context
          end
        end

        embedded_thinking
      end

      def process_tool(
        tool:,
        raw_context:,
        llm:,
        cancel:,
        update_blk:,
        prompt:,
        context:,
        current_thinking:
      )
        tool_call_id = tool.tool_call_id
        invocation_result_json = invoke_tool(tool, llm, cancel, context, &update_blk).to_json

        tool_call_message = {
          type: :tool_call,
          id: tool_call_id,
          content: { arguments: tool.parameters }.to_json,
          name: tool.name,
        }

        if current_thinking.present?
          current_thinking.each do |thinking|
            if thinking.redacted
              tool_call_message[:redacted_thinking_signature] = thinking.signature
            else
              tool_call_message[:thinking] = thinking.message
              tool_call_message[:thinking_signature] = thinking.signature
            end
          end
        end

        tool_message = {
          type: :tool,
          id: tool_call_id,
          content: invocation_result_json,
          name: tool.name,
        }

        if tool.standalone?
          standalone_context =
            context.dup.merge(
              conversation_context: [
                context[:conversation_context].last,
                tool_call_message,
                tool_message,
              ],
            )
          prompt = persona.craft_prompt(standalone_context)
        else
          prompt.push(**tool_call_message)
          prompt.push(**tool_message)
        end

        raw_context << [tool_call_message[:content], tool_call_id, "tool_call", tool.name]
        raw_context << [invocation_result_json, tool_call_id, "tool", tool.name]
      end

      def invoke_tool(tool, llm, cancel, context, &update_blk)
        show_placeholder = !context.skip_tool_details && !tool.class.allow_partial_tool_calls?

        update_blk.call("", cancel, build_placeholder(tool.summary, "")) if show_placeholder

        result =
          tool.invoke do |progress, render_raw|
            if render_raw
              update_blk.call("", cancel, tool.custom_raw, :partial_invoke)
              show_placeholder = false
            elsif show_placeholder
              placeholder = build_placeholder(tool.summary, progress)
              update_blk.call("", cancel, placeholder)
            end
          end

        if show_placeholder
          tool_details = build_placeholder(tool.summary, tool.details, custom_raw: tool.custom_raw)
          update_blk.call(tool_details, cancel, nil, :tool_details)
        elsif tool.custom_raw.present?
          update_blk.call(tool.custom_raw, cancel, nil, :custom_raw)
        end

        result
      end

      def self.guess_model(bot_user)
        associated_llm = LlmModel.find_by(user_id: bot_user.id)

        return if associated_llm.nil? # Might be a persona user. Handled by constructor.

        associated_llm
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
