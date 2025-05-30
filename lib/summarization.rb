# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class << self
      def topic_summary(topic)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_agent = AiAgent.find_by(id: SiteSetting.ai_summarization_agent)).blank?
          return nil
        end

        agent_klass = ai_agent.class_instance
        llm_model = find_summarization_model(agent_klass)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          build_bot(agent_klass, llm_model),
          DiscourseAi::Summarization::Strategies::TopicSummary.new(topic),
        )
      end

      def topic_gist(topic)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_agent = AiAgent.find_by(id: SiteSetting.ai_summary_gists_agent)).blank?
          return nil
        end

        agent_klass = ai_agent.class_instance
        llm_model = find_summarization_model(agent_klass)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          build_bot(agent_klass, llm_model),
          DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic),
        )
      end

      def chat_channel_summary(channel, time_window_in_hours)
        return nil if !SiteSetting.ai_summarization_enabled
        if (ai_agent = AiAgent.find_by(id: SiteSetting.ai_summarization_agent)).blank?
          return nil
        end

        agent_klass = ai_agent.class_instance
        llm_model = find_summarization_model(agent_klass)
        return nil if llm_model.blank?

        DiscourseAi::Summarization::FoldContent.new(
          build_bot(agent_klass, llm_model),
          DiscourseAi::Summarization::Strategies::ChatMessages.new(channel, time_window_in_hours),
          persist_summaries: false,
        )
      end

      # Priorities are:
      #   1. Agent's default LLM
      #   2. Hidden `ai_summarization_model` setting
      #   3. Newest LLM config
      def find_summarization_model(agent_klass)
        model_id =
          agent_klass.default_llm_id || SiteSetting.ai_summarization_model&.split(":")&.last # Remove legacy custom provider.

        if model_id.present?
          LlmModel.find_by(id: model_id)
        else
          LlmModel.last
        end
      end

      ### Private

      def build_bot(agent_klass, llm_model)
        agent = agent_klass.new
        user = User.find_by(id: agent_klass.user_id) || Discourse.system_user

        bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm_model)
      end
    end
  end
end
