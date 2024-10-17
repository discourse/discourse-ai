# frozen_string_literal: true

module DiscourseAi
  module Summarization
    def self.topic_summary(topic)
      if SiteSetting.ai_summarization_model.present? && SiteSetting.ai_summarization_enabled
        DiscourseAi::Summarization::FoldContent.new(
          DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_summarization_model),
          DiscourseAi::Summarization::Strategies::TopicSummary.new(topic),
        )
      else
        nil
      end
    end

    def self.topic_gist(topic)
      if SiteSetting.ai_summarization_model.present? && SiteSetting.ai_summarization_enabled
        DiscourseAi::Summarization::FoldContent.new(
          DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_summarization_model),
          DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic),
        )
      else
        nil
      end
    end

    def self.chat_channel_summary(channel, time_window_in_hours)
      if SiteSetting.ai_summarization_model.present? && SiteSetting.ai_summarization_enabled
        DiscourseAi::Summarization::FoldContent.new(
          DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_summarization_model),
          DiscourseAi::Summarization::Strategies::ChatMessages.new(channel, time_window_in_hours),
          persist_summaries: false,
        )
      else
        nil
      end
    end
  end
end
