# frozen_string_literal: true

describe DiscourseAi::TopicSummarization do
  fab!(:user) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  before do
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
  end

  let(:strategy) { DiscourseAi::Summarization.default_strategy }

  shared_examples "includes only public-visible topics" do
    subject { DiscourseAi::TopicSummarization.new(strategy, topic, user) }

    it "only includes visible posts" do
      topic.first_post.update!(hidden: true)

      posts = subject.summary_targets

      expect(posts.none?(&:hidden?)).to eq(true)
    end

    it "doesn't include posts without users" do
      topic.first_post.user.destroy!

      posts = subject.summary_targets

      expect(posts.detect { |p| p.id == topic.first_post.id }).to be_nil
    end

    it "doesn't include deleted posts" do
      topic.first_post.update!(user_id: nil)

      posts = subject.summary_targets

      expect(posts.detect { |p| p.id == topic.first_post.id }).to be_nil
    end
  end

  describe "#summary_targets" do
    context "when the topic has a best replies summary" do
      before { topic.has_summary = true }

      it_behaves_like "includes only public-visible topics"
    end

    context "when the topic doesn't have a best replies summary" do
      before { topic.has_summary = false }

      it_behaves_like "includes only public-visible topics"
    end
  end

  describe "#summarize" do
    subject(:summarization) { described_class.new(strategy, topic, user) }

    def assert_summary_is_cached(topic, summary_response)
      cached_summary = AiSummary.find_by(target: topic)

      expect(cached_summary.content_range).to cover(*topic.posts.map(&:post_number))
      expect(cached_summary.summarized_text).to eq(summary)
      expect(cached_summary.original_content_sha).to be_present
      expect(cached_summary.algorithm).to eq("fake")
    end

    context "when the content was summarized in a single chunk" do
      let(:summary) { "This is the final summary" }

      it "caches the summary" do
        DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
          section = summarization.summarize
          expect(section.summarized_text).to eq(summary)
          assert_summary_is_cached(topic, summary)
        end
      end

      it "returns the cached version in subsequent calls" do
        summarization.summarize

        cached_summary_text = "This is a cached summary"
        AiSummary.find_by(target: topic).update!(
          summarized_text: cached_summary_text,
          updated_at: 24.hours.ago,
        )

        summarization = described_class.new(strategy, topic, user)
        section = summarization.summarize
        expect(section.summarized_text).to eq(cached_summary_text)
      end

      context "when the topic has embed content cached" do
        it "embed content is used instead of the raw text" do
          topic_embed =
            Fabricate(
              :topic_embed,
              topic: topic,
              embed_content_cache: "<p>hello world new post :D</p>",
            )

          DiscourseAi::Completions::Llm.with_prepared_responses(["A summary"]) do |spy|
            summarization.summarize

            prompt_raw =
              spy
                .prompt_messages
                .reduce(+"") do |memo, m|
                  memo << m[:content] << "\n"

                  memo
                end

            expect(prompt_raw).to include(topic_embed.embed_content_cache)
          end
        end
      end
    end

    describe "invalidating cached summaries" do
      let(:cached_text) { "This is a cached summary" }
      let(:updated_summary) { "This is the final summary" }

      def cached_summary
        AiSummary.find_by(target: topic)
      end

      before do
        # a bit tricky, but fold_content now caches an instance of LLM
        # once it is cached with_prepared_responses will not work as expected
        # since it is glued to the old llm instance
        # so we create the cached summary totally independantly
        DiscourseAi::Completions::Llm.with_prepared_responses([cached_text]) do
          strategy = DiscourseAi::Summarization.default_strategy
          described_class.new(strategy, topic, user).summarize
        end

        cached_summary.update!(summarized_text: cached_text, created_at: 24.hours.ago)
      end

      context "when the user can requests new summaries" do
        context "when there are no new posts" do
          it "returns the cached summary" do
            section = summarization.summarize

            expect(section.summarized_text).to eq(cached_text)
          end
        end

        context "when there are new posts" do
          before { cached_summary.update!(original_content_sha: "outdated_sha") }

          it "returns a new summary" do
            DiscourseAi::Completions::Llm.with_prepared_responses([updated_summary]) do
              section = summarization.summarize

              expect(section.summarized_text).to eq(updated_summary)
            end
          end

          context "when the cached summary is less than one hour old" do
            before { cached_summary.update!(created_at: 30.minutes.ago) }

            it "returns the cached summary" do
              cached_summary.update!(created_at: 30.minutes.ago)

              section = summarization.summarize

              expect(section.summarized_text).to eq(cached_text)
              expect(section.outdated).to eq(true)
            end

            it "returns a new summary if the skip_age_check flag is passed" do
              DiscourseAi::Completions::Llm.with_prepared_responses([updated_summary]) do
                section = summarization.summarize(skip_age_check: true)

                expect(section.summarized_text).to eq(updated_summary)
              end
            end
          end
        end
      end
    end

    describe "stream partial updates" do
      let(:summary) { "This is the final summary" }

      it "receives a blk that is passed to the underlying strategy and called with partial summaries" do
        partial_result = +""

        DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
          summarization.summarize { |partial_summary| partial_result << partial_summary }
        end

        expect(partial_result).to eq(summary)
      end
    end
  end
end
