# frozen_string_literal: true

require "rails_helper"

module DiscourseAi
  module Automation
    describe ReportRunner do
      fab!(:user)
      fab!(:reciever) { Fabricate(:user) }
      fab!(:post) { Fabricate(:post, user: user) }
      fab!(:group)
      fab!(:secure_category) { Fabricate(:private_category, group: group) }
      fab!(:secure_topic) { Fabricate(:topic, category: secure_category) }
      fab!(:secure_post) { Fabricate(:post, raw: "Top secret date !!!!", topic: secure_topic) }

      describe "#run!" do
        it "generates correctly respects the params" do
          DiscourseAi::Completions::Llm.with_prepared_responses(["magical report"]) do
            ReportRunner.run!(
              sender_username: user.username,
              receivers: [reciever.username],
              title: "test report",
              model: "gpt-4",
              category_ids: nil,
              tags: nil,
              allow_secure_categories: false,
              debug_mode: true,
              sample_size: 100,
              instructions: "make a magic report",
              days: 7,
              offset: 0,
              priority_group_id: nil,
              tokens_per_post: 150,
            )
          end

          report = Topic.where(title: "test report").first
          expect(report.ordered_posts.first.raw).to eq("magical report")
          debugging = report.ordered_posts.last.raw

          expect(debugging).to include(post.raw)
          expect(debugging).not_to include(secure_post.raw)
        end
      end
    end
  end
end
