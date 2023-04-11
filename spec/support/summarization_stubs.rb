# frozen_string_literal: true

class SummarizationStubs
  class << self
    def test_summary
      "This is a summary"
    end

    def openai_response(content)
      {
        id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
        object: "chat.completion",
        created: 1_678_464_820,
        model: "gpt-3.5-turbo-0301",
        usage: {
          prompt_tokens: 337,
          completion_tokens: 162,
          total_tokens: 499,
        },
        choices: [
          { message: { role: "assistant", content: content }, finish_reason: "stop", index: 0 },
        ],
      }
    end

    def openai_chat_summarization_stub(chat_messages)
      prompt_messages =
        chat_messages
          .sort_by(&:created_at)
          .map { |m| "#{m.user.username_lower}: #{m.message}" }
          .join("\n")

      summary_prompt = [{ role: "system", content: <<~TEXT }]
        Summarize the following article:\n\n#{prompt_messages}
      TEXT

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: { model: "gpt-4", messages: summary_prompt }.to_json)
        .to_return(status: 200, body: JSON.dump(openai_response(test_summary)))
    end

    def openai_topic_summarization_stub(topic, user)
      prompt_posts = TopicView.new(topic, user, { filter: "summary" }).posts.map(&:raw).join("\n")

      summary_prompt = [{ role: "system", content: <<~TEXT }]
        Summarize the following article:\n\n#{prompt_posts}
      TEXT

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: { model: "gpt-4", messages: summary_prompt }.to_json)
        .to_return(status: 200, body: JSON.dump(openai_response(test_summary)))
    end
  end
end
