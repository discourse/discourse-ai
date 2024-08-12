# frozen_string_literal: true

RSpec.describe Jobs::StreamPostHelper do
  subject(:job) { described_class.new }

  before { assign_fake_provider_to(:ai_helper_model) }

  describe "#execute" do
    fab!(:topic)
    fab!(:post) do
      Fabricate(
        :post,
        topic: topic,
        raw:
          "I like to eat pie. It is a very good dessert. Some people are wasteful by throwing pie at others but I do not do that. I always eat the pie.",
      )
    end
    fab!(:user) { Fabricate(:leader) }

    before do
      Group.find(Group::AUTO_GROUPS[:trust_level_3]).add(user)
      SiteSetting.ai_helper_enabled = true
    end

    describe "validates params" do
      let(:mode) { CompletionPrompt::EXPLAIN }
      let(:prompt) { CompletionPrompt.find_by(id: mode) }

      it "does nothing if there is no post" do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/streamed_suggestion/#{post.id}") do
            job.execute(post_id: nil, user_id: user.id, text: "pie", prompt: mode)
          end

        expect(messages).to be_empty
      end

      it "does nothing if there is no user" do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/explain/#{post.id}") do
            job.execute(post_id: post.id, user_id: nil, term_to_explain: "pie", prompt: mode)
          end

        expect(messages).to be_empty
      end

      it "does nothing if there is no text" do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/streamed_suggestion/#{post.id}") do
            job.execute(post_id: post.id, user_id: user.id, text: nil, prompt: mode)
          end

        expect(messages).to be_empty
      end
    end

    context "when the prompt is explain" do
      let(:mode) { CompletionPrompt::EXPLAIN }
      let(:prompt) { CompletionPrompt.find_by(id: mode) }

      it "publishes updates with a partial result" do
        explanation =
          "In this context, \"pie\" refers to a baked dessert typically consisting of a pastry crust and filling."

        partial_explanation = "I"

        DiscourseAi::Completions::Llm.with_prepared_responses([explanation]) do
          messages =
            MessageBus.track_publish("/discourse-ai/ai-helper/stream_suggestion/#{post.id}") do
              job.execute(post_id: post.id, user_id: user.id, text: "pie", prompt: prompt.name)
            end

          partial_result_update = messages.first.data
          expect(partial_result_update[:done]).to eq(false)
          expect(partial_result_update[:result]).to eq(partial_explanation)
        end
      end

      it "publishes a final update to signal we're done" do
        explanation =
          "In this context, \"pie\" refers to a baked dessert typically consisting of a pastry crust and filling."

        DiscourseAi::Completions::Llm.with_prepared_responses([explanation]) do
          messages =
            MessageBus.track_publish("/discourse-ai/ai-helper/stream_suggestion/#{post.id}") do
              job.execute(post_id: post.id, user_id: user.id, text: "pie", prompt: prompt.name)
            end

          final_update = messages.last.data
          expect(final_update[:result]).to eq(explanation)
          expect(final_update[:done]).to eq(true)
        end
      end
    end

    context "when the prompt is translate" do
      let(:mode) { CompletionPrompt::TRANSLATE }
      let(:prompt) { CompletionPrompt.find_by(id: mode) }

      it "publishes updates with a partial result" do
        sentence = "I like to eat pie."
        translation = "Me gusta comer pastel."
        partial_translation = "M"

        DiscourseAi::Completions::Llm.with_prepared_responses([translation]) do
          messages =
            MessageBus.track_publish("/discourse-ai/ai-helper/stream_suggestion/#{post.id}") do
              job.execute(post_id: post.id, user_id: user.id, text: sentence, prompt: prompt.name)
            end

          partial_result_update = messages.first.data
          expect(partial_result_update[:done]).to eq(false)
          expect(partial_result_update[:result]).to eq(partial_translation)
        end
      end

      it "publishes a final update to signal we're done" do
        sentence = "I like to eat pie."
        translation = "Me gusta comer pastel."

        DiscourseAi::Completions::Llm.with_prepared_responses([translation]) do
          messages =
            MessageBus.track_publish("/discourse-ai/ai-helper/stream_suggestion/#{post.id}") do
              job.execute(post_id: post.id, user_id: user.id, text: sentence, prompt: prompt.name)
            end

          final_update = messages.last.data
          expect(final_update[:result]).to eq(translation)
          expect(final_update[:done]).to eq(true)
        end
      end
    end
  end
end
