# frozen_string_literal: true

module Jobs
  class StreamDiscoverReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if (user = User.find_by(id: args[:user_id])).nil?
      return if (query = args[:query]).blank?

      ai_agent_klass =
        AiAgent
          .all_agents(enabled_only: false)
          .find { |agent| agent.id == SiteSetting.ai_bot_discover_agent.to_i }

      if ai_agent_klass.nil? || !user.in_any_groups?(ai_agent_klass.allowed_group_ids.to_a)
        return
      end
      return if (llm_model = LlmModel.find_by(id: ai_agent_klass.default_llm_id)).nil?

      bot =
        DiscourseAi::Agents::Bot.as(
          Discourse.system_user,
          agent: ai_agent_klass.new,
          model: llm_model,
        )

      streamed_reply = +""
      start = Time.now

      base = { query: query, model_used: llm_model.display_name }

      context =
        DiscourseAi::Agents::BotContext.new(
          messages: [{ type: :user, content: query }],
          skip_tool_details: true,
        )

      bot.reply(context) do |partial|
        streamed_reply << partial

        # Throttle updates.
        if (Time.now - start > 0.3) || Rails.env.test?
          payload = base.merge(done: false, ai_discover_reply: streamed_reply)
          publish_update(user, payload)
          start = Time.now
        end
      end

      publish_update(user, base.merge(done: true, ai_discover_reply: streamed_reply))
    end

    def publish_update(user, payload)
      MessageBus.publish("/discourse-ai/ai-bot/discover", payload, user_ids: [user.id])
    end
  end
end
