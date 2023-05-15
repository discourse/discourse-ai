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

        send("#{summarization_provider}_summarization", content)
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
        truncated_content = DiscourseAi::Tokenizer::BertTokenizer.truncate(content, max_length)

        ::DiscourseAi::Inference::DiscourseClassifier.perform!(
          "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
          model,
          truncated_content,
          SiteSetting.ai_summarization_discourse_service_api_key,
        ).dig(:summary_text)
      end

      def openai_summarization(content)
        truncated_content =
          DiscourseAi::Tokenizer::OpenAiTokenizer.truncate(content, max_length - 50)

        messages = [{ role: "system", content: <<~TEXT }]
          Summarize the following article:\n\n#{truncated_content}
        TEXT

        ::DiscourseAi::Inference::OpenAiCompletions.perform!(messages, model).dig(
          :choices,
          0,
          :message,
          :content,
        )
      end

      def anthropic_summarization(content)
        truncated_content =
          DiscourseAi::Tokenizer::AnthropicTokenizer.truncate(content, max_length - 50)

        messages =
          "Human: Summarize the following article that is inside <input> tags.
          Please include only the summary inside <ai> tags.

          <input>##{truncated_content}</input>


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
          "bart-large-cnn-samsum" => 1024,
          "flan-t5-base-samsum" => 512,
          "long-t5-tglobal-base-16384-book-summary" => 16_384,
          "gpt-3.5-turbo" => 4096,
          "gpt-4" => 8192,
          "claude-v1" => 9000,
          "claude-v1-100k" => 100_000,
        }

        lengths[model]
      end
    end
  end
end
