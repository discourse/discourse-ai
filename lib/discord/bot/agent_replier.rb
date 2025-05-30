# frozen_string_literal: true

module DiscourseAi
  module Discord::Bot
    class AgentReplier < Base
      def initialize(body)
        @agent =
          AiAgent
            .all_agents(enabled_only: false)
            .find { |agent| agent.id == SiteSetting.ai_discord_search_agent.to_i }
            .new
        @bot =
          DiscourseAi::Agents::Bot.as(
            Discourse.system_user,
            agent: @agent,
            model: LlmModel.find(@agent.class.default_llm_id),
          )
        super(body)
      end

      def handle_interaction!
        last_update_sent_at = Time.now - 1
        reply = +""
        full_reply =
          @bot.reply(
            { conversation_context: [{ type: :user, content: @query }], skip_tool_details: true },
          ) do |partial, _something|
            reply << partial
            next if reply.blank?

            if @reply_response.nil?
              create_reply(wrap_links(reply.dup))
            elsif @last_update_response.nil?
              update_reply(wrap_links(reply.dup))
            elsif Time.now - last_update_sent_at > 1
              update_reply(wrap_links(reply.dup))
              last_update_sent_at = Time.now
            end
          end

        discord_reply = wrap_links(full_reply.last.first)

        if @reply_response.nil?
          create_reply(discord_reply)
        else
          update_reply(discord_reply)
        end
      end

      def wrap_links(text)
        text.gsub(%r{(?<url>https?://[^\s]+)}, "<\\k<url>>")
      end
    end
  end
end
