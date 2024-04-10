# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      attr_reader :model

      BOT_NOT_FOUND = Class.new(StandardError)
      MAX_COMPLETIONS = 5
      MAX_TOOLS = 5

      def self.as(bot_user, persona: DiscourseAi::AiBot::Personas::General.new, model: nil)
        new(bot_user, persona, model)
      end

      def initialize(bot_user, persona, model = nil)
        @bot_user = bot_user
        @persona = persona
        @model = model || self.class.guess_model(bot_user) || @persona.class.default_llm
      end

      attr_reader :bot_user
      attr_accessor :persona

      def get_updated_title(conversation_context, post)
        system_insts = <<~TEXT.strip
        You are titlebot. Given a topic, you will figure out a title.
        You will never respond with anything but 7 word topic title.
        TEXT

        title_prompt =
          DiscourseAi::Completions::Prompt.new(
            system_insts,
            messages: conversation_context,
            topic_id: post.topic_id,
            post_id: post.id,
          )

        title_prompt.push(
          type: :user,
          content:
            "Based on our previous conversation, suggest a 7 word title without quoting any of it.",
        )

        DiscourseAi::Completions::Llm
          .proxy(model)
          .generate(title_prompt, user: post.user)
          .strip
          .split("\n")
          .last
      end

      def reply(context, &update_blk)
        prompt = persona.craft_prompt(context)

        total_completions = 0
        ongoing_chain = true
        raw_context = []

        user = context[:user]

        llm_kwargs = { user: user }
        llm_kwargs[:temperature] = persona.temperature if persona.temperature
        llm_kwargs[:top_p] = persona.top_p if persona.top_p

        while total_completions <= MAX_COMPLETIONS && ongoing_chain
          current_model = model
          llm = DiscourseAi::Completions::Llm.proxy(current_model)
          tool_found = false

          result =
            llm.generate(prompt, **llm_kwargs) do |partial, cancel|
              tools = persona.find_tools(partial)

              if (tools.present?)
                tool_found = true
                tools[0..MAX_TOOLS].each do |tool|
                  ongoing_chain &&= tool.chain_next_response?
                  process_tool(tool, raw_context, llm, cancel, update_blk, prompt)
                end
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

      private

      def process_tool(tool, raw_context, llm, cancel, update_blk, prompt)
        tool_call_id = tool.tool_call_id
        invocation_result_json = invoke_tool(tool, llm, cancel, &update_blk).to_json

        tool_call_message = {
          type: :tool_call,
          id: tool_call_id,
          content: { arguments: tool.parameters }.to_json,
          name: tool.name,
        }

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

      def self.guess_model(bot_user)
        # HACK(roman): We'll do this until we define how we represent different providers in the bot settings
        case bot_user.id
        when DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID
          if DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?("claude-2")
            "aws_bedrock:claude-2"
          else
            "anthropic:claude-2"
          end
        when DiscourseAi::AiBot::EntryPoint::GPT4_ID
          "open_ai:gpt-4"
        when DiscourseAi::AiBot::EntryPoint::GPT4_TURBO_ID
          "open_ai:gpt-4-turbo"
        when DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID
          "open_ai:gpt-3.5-turbo-16k"
        when DiscourseAi::AiBot::EntryPoint::MIXTRAL_ID
          if DiscourseAi::Completions::Endpoints::Vllm.correctly_configured?(
               "mistralai/Mixtral-8x7B-Instruct-v0.1",
             )
            "vllm:mistralai/Mixtral-8x7B-Instruct-v0.1"
          else
            "hugging_face:mistralai/Mixtral-8x7B-Instruct-v0.1"
          end
        when DiscourseAi::AiBot::EntryPoint::GEMINI_ID
          "google:gemini-pro"
        when DiscourseAi::AiBot::EntryPoint::FAKE_ID
          "fake:fake"
        when DiscourseAi::AiBot::EntryPoint::CLAUDE_3_OPUS_ID
          # no bedrock support yet 18-03
          "anthropic:claude-3-opus"
        when DiscourseAi::AiBot::EntryPoint::COHERE_COMMAND_R_PLUS
          "cohere:command-r-plus"
        when DiscourseAi::AiBot::EntryPoint::CLAUDE_3_SONNET_ID
          if DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?(
               "claude-3-sonnet",
             )
            "aws_bedrock:claude-3-sonnet"
          else
            "anthropic:claude-3-sonnet"
          end
        when DiscourseAi::AiBot::EntryPoint::CLAUDE_3_HAIKU_ID
          if DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?("claude-3-haiku")
            "aws_bedrock:claude-3-haiku"
          else
            "anthropic:claude-3-haiku"
          end
        else
          nil
        end
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
