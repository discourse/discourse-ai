# frozen_string_literal: true

describe DiscourseAi::Utils::Research::Filter do
  describe "integration tests" do
    before_all do
      SiteSetting.min_topic_title_length = 3
      SiteSetting.min_agentl_message_title_length = 3
    end

    fab!(:user)

    fab!(:feature_tag) { Fabricate(:tag, name: "feature") }
    fab!(:bug_tag) { Fabricate(:tag, name: "bug") }

    fab!(:announcement_category) { Fabricate(:category, name: "Announcements") }
    fab!(:feedback_category) { Fabricate(:category, name: "Feedback") }

    fab!(:feature_topic) do
      Fabricate(
        :topic,
        user: user,
        tags: [feature_tag],
        category: announcement_category,
        title: "New Feature Discussion",
      )
    end

    fab!(:bug_topic) do
      Fabricate(
        :topic,
        tags: [bug_tag],
        user: user,
        category: announcement_category,
        title: "Bug Report",
      )
    end

    fab!(:feature_bug_topic) do
      Fabricate(
        :topic,
        tags: [feature_tag, bug_tag],
        user: user,
        category: feedback_category,
        title: "Feature with Bug",
      )
    end

    fab!(:no_tag_topic) do
      Fabricate(:topic, user: user, category: feedback_category, title: "General Discussion")
    end

    fab!(:feature_post) { Fabricate(:post, topic: feature_topic, user: user) }
    fab!(:bug_post) { Fabricate(:post, topic: bug_topic, user: user) }
    fab!(:feature_bug_post) { Fabricate(:post, topic: feature_bug_topic, user: user) }
    fab!(:no_tag_post) { Fabricate(:post, topic: no_tag_topic, user: user) }

    describe "security filtering" do
      fab!(:secure_group) { Fabricate(:group) }
      fab!(:secure_category) { Fabricate(:category, name: "Secure") }

      fab!(:secure_topic) do
        secure_category.set_permissions(secure_group => :readonly)
        secure_category.save!
        Fabricate(
          :topic,
          category: secure_category,
          user: user,
          title: "This is a secret Secret Topic",
        )
      end

      fab!(:secure_post) { Fabricate(:post, topic: secure_topic, user: user) }

      fab!(:pm_topic) { Fabricate(:private_message_topic, user: user) }
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: user) }

      it "omits secure categories when no guardian is supplied" do
        filter = described_class.new("")
        expect(filter.search.pluck(:id)).not_to include(secure_post.id)

        user.groups << secure_group
        guardian = Guardian.new(user)
        filter_with_guardian = described_class.new("", guardian: guardian)
        expect(filter_with_guardian.search.pluck(:id)).to include(secure_post.id)
      end

      it "omits PMs unconditionally" do
        filter = described_class.new("")
        expect(filter.search.pluck(:id)).not_to include(pm_post.id)

        guardian = Guardian.new(user)
        filter_with_guardian = described_class.new("", guardian: guardian)
        expect(filter_with_guardian.search.pluck(:id)).not_to include(pm_post.id)
      end
    end

    describe "tag filtering" do
      it "correctly filters posts by tags" do
        filter = described_class.new("tag:feature")
        expect(filter.search.pluck(:id)).to contain_exactly(feature_post.id, feature_bug_post.id)

        filter = described_class.new("tag:feature,bug")
        expect(filter.search.pluck(:id)).to contain_exactly(
          feature_bug_post.id,
          bug_post.id,
          feature_post.id,
        )

        filter = described_class.new("tags:bug")
        expect(filter.search.pluck(:id)).to contain_exactly(bug_post.id, feature_bug_post.id)

        filter = described_class.new("tag:nonexistent")
        expect(filter.search.count).to eq(0)
      end
    end

    describe "category filtering" do
      it "correctly filters posts by categories" do
        filter = described_class.new("category:Announcements")
        expect(filter.search.pluck(:id)).to contain_exactly(feature_post.id, bug_post.id)

        # it can tack on topics
        filter =
          described_class.new(
            "category:Announcements topic:#{feature_bug_post.topic.id},#{no_tag_post.topic.id}",
          )
        expect(filter.search.pluck(:id)).to contain_exactly(
          feature_post.id,
          bug_post.id,
          feature_bug_post.id,
          no_tag_post.id,
        )

        filter = described_class.new("category:Announcements,Feedback")
        expect(filter.search.pluck(:id)).to contain_exactly(
          feature_post.id,
          bug_post.id,
          feature_bug_post.id,
          no_tag_post.id,
        )

        filter = described_class.new("categories:Feedback")
        expect(filter.search.pluck(:id)).to contain_exactly(feature_bug_post.id, no_tag_post.id)

        filter = described_class.new("category:Feedback tag:feature")
        expect(filter.search.pluck(:id)).to contain_exactly(feature_bug_post.id)
      end
    end

    it "can limit number of results" do
      filter = described_class.new("category:Feedback max_results:1", limit: 5)
      expect(filter.search.pluck(:id).length).to eq(1)
    end

    describe "full text keyword searching" do
      before_all { SearchIndexer.enable }
      fab!(:post_with_apples) do
        Fabricate(:post, raw: "This post contains apples", topic: feature_topic, user: user)
      end

      fab!(:post_with_bananas) do
        Fabricate(:post, raw: "This post mentions bananas", topic: bug_topic, user: user)
      end

      fab!(:post_with_both) do
        Fabricate(
          :post,
          raw: "This post has apples and bananas",
          topic: feature_bug_topic,
          user: user,
        )
      end

      fab!(:post_with_none) do
        Fabricate(:post, raw: "No fruits here", topic: no_tag_topic, user: user)
      end

      it "correctly filters posts by full text keywords" do
        filter = described_class.new("keywords:apples")
        expect(filter.search.pluck(:id)).to contain_exactly(post_with_apples.id, post_with_both.id)

        filter = described_class.new("keywords:bananas")
        expect(filter.search.pluck(:id)).to contain_exactly(post_with_bananas.id, post_with_both.id)

        filter = described_class.new("keywords:apples,bananas")
        expect(filter.search.pluck(:id)).to contain_exactly(
          post_with_apples.id,
          post_with_bananas.id,
          post_with_both.id,
        )

        filter = described_class.new("keywords:oranges")
        expect(filter.search.count).to eq(0)
      end
    end
  end
end
