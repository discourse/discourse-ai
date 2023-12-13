# frozen_string_literal: true

RSpec.describe Jobs::StreamPostHelper do
  subject(:job) { described_class.new }

  describe "#execute" do
    fab!(:topic) { Fabricate(:topic) }
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
      SiteSetting.composer_ai_helper_enabled = true
    end

    describe "validates params" do
      it "does nothing if there is no post" do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/explain/#{post.id}") do
            job.execute(post_id: nil, user_id: user.id, term_to_explain: "pie")
          end

        expect(messages).to be_empty
      end

      it "does nothing if there is no user" do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/explain/#{post.id}") do
            job.execute(post_id: post.id, user_id: nil, term_to_explain: "pie")
          end

        expect(messages).to be_empty
      end

      it "does nothing if there is no term to explain" do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/explain/#{post.id}") do
            job.execute(post_id: post.id, user_id: user.id, term_to_explain: nil)
          end

        expect(messages).to be_empty
      end
    end

    it "publishes updates with a partial result" do
      explanation =
        "I"

      DiscourseAi::Completions::Llm.with_prepared_responses([explanation]) do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/explain/#{post.id}") do
            job.execute(post_id: post.id, user_id: user.id, term_to_explain: "pie")
          end

        partial_result_update = messages.first.data
        expect(partial_result_update[:done]).to eq(false)
        expect(partial_result_update[:result]).to eq(explanation)
      end
    end

    it "publishes a final update to signal we're donea" do
      explanation =
        "In this context, \"pie\" refers to a baked dessert typically consisting of a pastry crust and filling."

      DiscourseAi::Completions::Llm.with_prepared_responses([explanation]) do
        messages =
          MessageBus.track_publish("/discourse-ai/ai-helper/explain/#{post.id}") do
            job.execute(post_id: post.id, user_id: user.id, term_to_explain: "pie")
          end

        final_update = messages.last.data
        expect(final_update[:result]).to eq(explanation)
        expect(final_update[:done]).to eq(true)
      end
    end
  end
end
