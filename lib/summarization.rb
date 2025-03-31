# frozen_string_literal: true

module DiscourseAi
  module Summarization
    def self.topic_summary(topic)
      return nil if !SiteSetting.ai_summarization_enabled
      return nil if (model = SiteSetting.ai_summarization_model).blank?
      if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summarization_persona)).blank?
        return nil
      end

      DiscourseAi::Summarization::FoldContent.new(
        build_bot(ai_persona, model),
        DiscourseAi::Summarization::Strategies::TopicSummary.new(topic),
      )
    end

    def self.topic_gist(topic)
      return nil if !SiteSetting.ai_summarization_enabled
      return nil if (model = SiteSetting.ai_summarization_model).blank?
      if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summary_gists_persona)).blank?
        return nil
      end

      if SiteSetting.ai_summarization_model.present? && SiteSetting.ai_summarization_enabled
        DiscourseAi::Summarization::FoldContent.new(
          build_bot(ai_persona, model),
          DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic),
        )
      else
        nil
      end
    end

    def self.chat_channel_summary(channel, time_window_in_hours)
      return nil if !SiteSetting.ai_summarization_enabled
      return nil if (model = SiteSetting.ai_summarization_model).blank?
      if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summarization_persona)).blank?
        return nil
      end

      DiscourseAi::Summarization::FoldContent.new(
        build_bot(ai_persona, model),
        DiscourseAi::Summarization::Strategies::ChatMessages.new(channel, time_window_in_hours),
        persist_summaries: false,
      )
    end

    ### Private

    def self.build_bot(ai_persona, default_model)
      persona_class = ai_persona.class_instance
      persona = persona_class.new
      user = User.find_by(id: persona_class.user_id) || Discourse.system_user

      bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: default_model)
    end
  end
end
