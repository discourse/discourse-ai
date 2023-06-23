# frozen_string_literal: true

require_relative "../../../../../support/openai_completions_inference_stubs"
require_relative "../../../../../support/anthropic_completion_stubs"

RSpec.describe Jobs::CreateAiReply do
  before do
    # got to do this cause we include times in system message
    freeze_time
  end

  describe "#execute" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    let(:expected_response) do
      "Hello this is a bot and what you just said is an interesting question"
    end

    before { SiteSetting.min_personal_message_post_length = 5 }

    context "when chatting with the Open AI bot" do
      let(:deltas) { expected_response.split(" ").map { |w| { content: "#{w} " } } }

      before do
        bot_user = User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID)
        bot = DiscourseAi::AiBot::Bot.as(bot_user)

        # time needs to be frozen so time in prompt does not drift
        freeze_time

        OpenAiCompletionsInferenceStubs.stub_streamed_response(
          DiscourseAi::AiBot::OpenAiBot.new(bot_user).bot_prompt_with_topic_context(post),
          deltas,
          model: bot.model_for,
          req_opts: {
            temperature: 0.4,
            top_p: 0.9,
            max_tokens: 2500,
            functions: bot.available_functions,
            stream: true,
          },
        )
      end

      it "adds a reply from the GPT bot" do
        subject.execute(
          post_id: topic.first_post.id,
          bot_user_id: DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID,
        )

        expect(topic.posts.last.raw).to eq(expected_response)
      end

      it "streams the reply on the fly to the client through MB" do
        messages =
          MessageBus.track_publish("discourse-ai/ai-bot/topic/#{topic.id}") do
            subject.execute(
              post_id: topic.first_post.id,
              bot_user_id: DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID,
            )
          end

        done_signal = messages.pop

        expect(messages.length).to eq(deltas.length)

        messages.each_with_index do |m, idx|
          expect(m.data[:raw]).to eq(deltas[0..(idx + 1)].map { |d| d[:content] }.join)
        end

        expect(done_signal.data[:done]).to eq(true)
      end
    end

    context "when chatting with Claude from Anthropic" do
      let(:claude_response) { "#{expected_response}" }
      let(:deltas) { claude_response.split(" ").map { |w| "#{w} " } }

      before do
        bot_user = User.find(DiscourseAi::AiBot::EntryPoint::CLAUDE_V1_ID)

        AnthropicCompletionStubs.stub_streamed_response(
          DiscourseAi::AiBot::AnthropicBot.new(bot_user).bot_prompt_with_topic_context(post),
          deltas,
          model: "claude-v1.3",
          req_opts: {
            temperature: 0.4,
            max_tokens_to_sample: 3000,
            stream: true,
          },
        )
      end

      it "adds a reply from the Claude bot" do
        subject.execute(
          post_id: topic.first_post.id,
          bot_user_id: DiscourseAi::AiBot::EntryPoint::CLAUDE_V1_ID,
        )

        expect(topic.posts.last.raw).to eq(expected_response)
      end
    end
  end
end
