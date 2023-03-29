# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryGenerator
      def summarize!(target)
        content = content_of(target)
        if model.starts_with?("gpt")
          openai_summarization(content)
        else
          discourse_summarization(content)
        end
      end

      def content_of(target_to_classify)
        case target_to_classify.class
        when Post
          target_to_classify.raw
        when Topic
          target_to_classify.posts.order(:post_number).pluck(:raw).join("\n")
        else
          raise "Invalid target to classify"
        end
      end

      def discourse_summarization(content)
        ::DiscourseAi::Inference::DiscourseClassifier.perform!(
          "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
          model,
          content,
          SiteSetting.ai_sentiment_inference_service_api_key,
        )
      end

      def openai_summarization(content)
        ::DiscourseAi::Inference::OpenAiCompletions.perform!([content], model)[:data].first[:text]
      end

      def model
        SiteSetting.ai_summarization_model
      end
    end
  end
end
