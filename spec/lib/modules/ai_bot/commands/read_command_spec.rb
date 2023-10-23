#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::ReadCommand do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  fab!(:parent_category) { Fabricate(:category, name: "animals") }
  fab!(:category) { Fabricate(:category, parent_category: parent_category, name: "amazing-cat") }

  fab!(:tag_funny) { Fabricate(:tag, name: "funny") }
  fab!(:tag_sad) { Fabricate(:tag, name: "sad") }
  fab!(:tag_hidden) { Fabricate(:tag, name: "hidden") }
  fab!(:staff_tag_group) do
    tag_group = Fabricate.build(:tag_group, name: "Staff only", tag_names: ["hidden"])

    tag_group.permissions = [
      [Group::AUTO_GROUPS[:staff], TagGroupPermission.permission_types[:full]],
    ]
    tag_group.save!
    tag_group
  end
  fab!(:topic_with_tags) do
    Fabricate(:topic, category: category, tags: [tag_funny, tag_sad, tag_hidden])
  end

  before { SiteSetting.ai_bot_enabled = true }

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
      expect(results[:content]).to include("animals")
      expect(results[:content]).not_to include("hidden")
      expect(read.description_args).to eq(
        title: topic_with_tags.title,
        url: topic_with_tags.relative_url,
      )
    end
  end
end
