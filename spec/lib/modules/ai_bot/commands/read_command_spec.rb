#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::ReadCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  fab!(:category) { Fabricate(:category, name: "amazing-cat") }
  fab!(:tag_funny) { Fabricate(:tag, name: "funny") }
  fab!(:tag_sad) { Fabricate(:tag, name: "sad") }
  fab!(:tag_hidden) { Fabricate(:tag, name: "hidden") }
  fab!(:staff_tag_group) { Fabricate(:tag_group, name: "Staff only", tag_names: ["hidden"]) }
  fab!(:topic_with_tags) do
    Fabricate(:topic, category: category, tags: [tag_funny, tag_sad, tag_hidden])
  end

  let(:staff) { Group::AUTO_GROUPS[:staff] }
  let(:full) { TagGroupPermission.permission_types[:full] }

  before do
    staff_tag_group.permissions = [[staff, full]]
    staff_tag_group.save!
  end

  describe "#process" do
    it "can read a topic" do
      topic_id = topic_with_tags.id

      Fabricate(:post, topic: topic_with_tags, raw: "hello there")
      Fabricate(:post, topic: topic_with_tags, raw: "mister sam")

      read = described_class.new(bot_user: bot_user, args: nil)

      results = read.process(topic_id: topic_id)

      expect(results[:topic_id]).to eq(topic_id)
      expect(results[:content]).to include("hello")
      expect(results[:content]).to include("sam")
      expect(results[:content]).to include("amazing-cat")
      expect(results[:content]).to include("funny")
      expect(results[:content]).to include("sad")
      expect(results[:content]).not_to include("hidden")
      expect(read.description_args).to eq(
        title: topic_with_tags.title,
        url: topic_with_tags.relative_url,
      )
    end
  end
end
