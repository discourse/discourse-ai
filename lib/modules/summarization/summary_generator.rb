# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryGenerator
      def initialize(target)
        @target = target
      end

      def summarize!(content_since)
        content = get_content(content_since)

        send("#{summarization_provider}_summarization", content)
      end

      private

      attr_reader :target

      def summarization_provider
        case model
        in "gpt-3.5-turbo"
          "openai"
        in "gpt-4"
          "openai"
        in "claude-v1"
          "anthropic"
        else
          "discourse"
        end
      end

      def get_content(content_since)
        case target
        in Post
          target.raw
        in Topic
          target.posts.order(:post_number).pluck(:raw).join("\n")
        in ::Chat::Channel
          target
            .chat_messages
            .where("chat_messages.created_at > ?", content_since.hours.ago)
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

      def anthropic_summarization(content)
        messages =
          "Human: Summarize the following article that is inside <input> tags.
          Plese include only the summary inside <ai> tags.

          <input>##{content}</input>


          Assistant:
        "

        response =
          ::DiscourseAi::Inference::AnthropicCompletions.perform!(messages).dig(:completion)

        Nokogiri::HTML5.fragment(response).at("ai").text
      end

      def model
        SiteSetting.ai_summarization_model
      end
    end
  end
end
