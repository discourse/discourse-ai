#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::Read do
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-3.5-turbo") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }
  let(:tool) { described_class.new({ topic_id: topic_with_tags.id }, bot_user: bot_user, llm: llm) }

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

  fab!(:post1) { Fabricate(:post, topic: topic_with_tags, raw: "hello there") }
  fab!(:post2) { Fabricate(:post, topic: topic_with_tags, raw: "mister sam") }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "can read private topics if allowed to" do
      category = topic_with_tags.category
      category.set_permissions(Group::AUTO_GROUPS[:staff] => :full)
      category.save!

      tool =
        described_class.new(
          { topic_id: topic_with_tags.id, post_numbers: [post1.post_number] },
          bot_user: bot_user,
          llm: llm,
        )
      results = tool.invoke

      expect(results[:description]).to eq("Topic not found")

      admin = Fabricate(:admin)

      tool =
        described_class.new(
          { topic_id: topic_with_tags.id, post_numbers: [post1.post_number] },
          bot_user: bot_user,
          llm: llm,
          persona_options: {
            "read_private" => true,
          },
          context: {
            user: admin,
          },
        )
      results = tool.invoke
      expect(results[:content]).to include("hello there")

      tool =
        described_class.new(
          { topic_id: topic_with_tags.id, post_numbers: [post1.post_number] },
          bot_user: bot_user,
          llm: llm,
          context: {
            user: admin,
          },
        )

      results = tool.invoke
      expect(results[:description]).to eq("Topic not found")
    end

    it "can read specific posts" do
      tool =
        described_class.new(
          { topic_id: topic_with_tags.id, post_numbers: [post1.post_number] },
          bot_user: bot_user,
          llm: llm,
        )
      results = tool.invoke

      expect(results[:content]).to include("hello there")
      expect(results[:content]).not_to include("mister sam")
    end
    it "can read a topic" do
      topic_id = topic_with_tags.id
      results = tool.invoke

      expect(results[:topic_id]).to eq(topic_id)
      expect(results[:content]).to include("hello")
      expect(results[:content]).to include("sam")
      expect(results[:content]).to include("amazing-cat")
      expect(results[:content]).to include("funny")
      expect(results[:content]).to include("sad")
      expect(results[:content]).to include("animals")
      expect(results[:content]).not_to include("hidden")
      expect(tool.title).to eq(topic_with_tags.title)
      expect(tool.url).to eq(topic_with_tags.relative_url)
    end
  end
end
