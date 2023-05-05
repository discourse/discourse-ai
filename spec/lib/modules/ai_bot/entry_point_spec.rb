# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::EntryPoint do
  describe "#inject_into" do
    describe "subscribes to the post_created event" do
      fab!(:admin) { Fabricate(:admin) }
      let(:gpt_bot) { Discourse.gpt_bot }
      fab!(:bot_allowed_group) { Fabricate(:group) }

      let(:post_args) do
        {
          title: "Dear AI, I want to ask a question",
          raw: "Hello, Can you please tell me a story?",
          archetype: Archetype.private_message,
          target_usernames: [gpt_bot.username].join(","),
          category: 1,
        }
      end

      before do
        SiteSetting.ai_bot_allowed_groups = bot_allowed_group.id
        bot_allowed_group.add(admin)
      end

      it "queues a job to generate a reply by the AI" do
        expect { PostCreator.create!(admin, post_args) }.to change(
          Jobs::CreateAiReply.jobs,
          :size,
        ).by(1)
      end

      context "when the post is not from a PM" do
        it "does nothing" do
          expect {
            PostCreator.create!(admin, post_args.merge(archetype: Archetype.default))
          }.not_to change(Jobs::CreateAiReply.jobs, :size)
        end
      end

      context "when the bot doesn't have access to the PM" do
        it "does nothing" do
          user_2 = Fabricate(:user)
          expect {
            PostCreator.create!(admin, post_args.merge(target_usernames: [user_2.username]))
          }.not_to change(Jobs::CreateAiReply.jobs, :size)
        end
      end

      context "when the user is not allowed to interact with the bot" do
        it "does nothing" do
          bot_allowed_group.remove(admin)
          expect { PostCreator.create!(admin, post_args) }.not_to change(
            Jobs::CreateAiReply.jobs,
            :size,
          )
        end
      end

      context "when the post was created by the bot" do
        it "does nothing" do
          gpt_topic_id = PostCreator.create!(admin, post_args).topic_id
          reply_args =
            post_args.except(:archetype, :target_usernames, :title).merge(topic_id: gpt_topic_id)

          expect { PostCreator.create!(gpt_bot, reply_args) }.not_to change(
            Jobs::CreateAiReply.jobs,
            :size,
          )
        end
      end
    end
  end
end
