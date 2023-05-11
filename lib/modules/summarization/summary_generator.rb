# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryGenerator
      def initialize(target, user)
        @target = target
        @user = user
      end

      def summarize!(content_since)
        content = get_content(content_since)

        send("#{summarization_provider}_summarization", content[0..(max_length - 1)])
      end

      private

      attr_reader :target, :user

      def summarization_provider
        case model
        in "gpt-3.5-turbo" | "gpt-4"
          "openai"
        in "claude-v1" | "claude-v1-100k"
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
          TopicView
            .new(
              target,
              user,
              {
                filter: "summary",
                exclude_deleted_users: true,
                exclude_hidden: true,
                show_deleted: false,
              },
            )
            .posts
            .pluck(:raw)
            .join("\n")
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
          raise "Can't find content to summarize"
        end
      end

      def discourse_summarization(content)
        ::DiscourseAi::Inference::DiscourseClassifier.perform!(
          "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
          model,
          content,
          SiteSetting.ai_summarization_discourse_service_api_key,
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
          ::DiscourseAi::Inference::AnthropicCompletions.perform!(messages, model).dig(:completion)

        Nokogiri::HTML5.fragment(response).at("ai").text
      end

      def model
        SiteSetting.ai_summarization_model
      end

      def max_length
        lengths = {
          "bart-large-cnn-samsum" => 1024 * 4,
          "flan-t5-base-samsum" => 512 * 4,
          "long-t5-tglobal-base-16384-book-summary" => 16_384 * 4,
          "gpt-3.5-turbo" => 4096 * 4,
          "gpt-4" => 8192 * 4,
          "claude-v1" => 9000 * 4,
          "claude-v1-100k" => 100_000 * 4,
        }

        lengths[model]
      end
    end
  end
end
