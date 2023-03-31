# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryGenerator
      class << self
        def summarize!(target)
          content = content_of(target)
          if model.starts_with?("gpt")
            openai_summarization(content)
          else
            discourse_summarization(content)
          end
        end

        def content_of(target_to_classify)
          case target_to_classify
          in Post
            target_to_classify.raw
          in Topic
            target_to_classify.posts.order(:post_number).pluck(:raw).join("\n")
          in ::Chat::Channel
            target_to_classify
              .chat_messages
              .where("chat_messages.created_at > ?", 1.day.ago)
              .includes(:user)
              .order(created_at: :asc)
              .pluck(:username_lower, :message)
              .map { "#{_1}: #{_2}" }
              .join("\n")
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
          ).dig(:summary_text)
        end

        def openai_summarization(content)
          messages = [{ role: "system", content: <<~TEXT }]
            Summarize the following article:\n\n#{content}
          TEXT

          ::DiscourseAi::Inference::OpenAiCompletions.perform!(messages, model).dig(
            :choices,
            0,
            :message,
            :content,
          )
        end

        def model
          SiteSetting.ai_summarization_model
        end
      end
    end
  end
end
