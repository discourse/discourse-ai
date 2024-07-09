# frozen_string_literal: true
module DiscourseAi
  module Summarization
    def self.default_strategy
      if SiteSetting.ai_summarization_model.present? && SiteSetting.ai_summarization_enabled
        DiscourseAi::Summarization::Strategies::FoldContent.new(SiteSetting.ai_summarization_model)
      else
        nil
      end
    end
  end
end
