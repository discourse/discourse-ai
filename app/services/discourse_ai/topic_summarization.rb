# frozen_string_literal: true

module DiscourseAi
  class TopicSummarization
    def self.summarize(topic, user, skip_age_check: false, &on_partial_blk)
      new(DiscourseAi::Summarization.default_strategy, topic, user).summarize(
        skip_age_check: skip_age_check,
        &on_partial_blk
      )
    end

    def self.cached_summary(topic, user)
      new(DiscourseAi::Summarization.default_strategy, topic, user).cached_summary
    end

    def initialize(strategy, topic, user)
      @strategy = strategy
      @topic = topic
      @user = user
    end

    attr_reader :strategy, :topic, :user

    def cached_summary
      existing_summary
    end

    def summarize(skip_age_check: false, &on_partial_blk)
      # Existing summary shouldn't be nil in this scenario because the controller checks its existence.
      return if !user && !existing_summary

      return existing_summary if use_cached?(skip_age_check)

      delete_cached_summaries! if existing_summary

      content = {
        resource_path: "#{Discourse.base_path}/t/-/#{topic.id}",
        content_title: topic.title,
        contents: [],
      }

      summary_targets_data.map do |(pn, raw, username)|
        raw_text = raw

        if pn == 1 && topic.topic_embed&.embed_content_cache.present?
          raw_text = topic.topic_embed&.embed_content_cache
        end

        content[:contents] << { poster: username, id: pn, text: raw_text }
      end

      summarization_result = strategy.summarize(content, user, &on_partial_blk)
      cache_summary(summarization_result)
    end

    def summary_targets
      topic.has_summary? ? best_replies : pick_selection
    end

    private

    def summary_sha
      @summary_sha ||= build_sha(summary_targets_data.map(&:first))
    end

    def summary_targets_data
      @summary_targets_data ||= summary_targets.pluck(:post_number, :raw, :username)
    end

    def existing_summary
      if !defined?(@existing_summary)
        @existing_summary = AiSummary.find_by(target: topic)
        if @existing_summary && existing_summary.original_content_sha != summary_sha
          @existing_summary.mark_as_outdated
        end
      end
      @existing_summary
    end

    def best_replies
      Post
        .summary(topic.id)
        .where("post_type = ?", Post.types[:regular])
        .where("NOT hidden")
        .joins(:user)
        .order(:post_number)
    end

    def pick_selection
      posts =
        Post
          .where(topic_id: topic.id)
          .where("post_type = ?", Post.types[:regular])
          .where("NOT hidden")
          .order(:post_number)

      post_numbers = posts.limit(5).pluck(:post_number)
      post_numbers += posts.reorder("posts.score desc").limit(50).pluck(:post_number)
      post_numbers += posts.reorder("post_number desc").limit(5).pluck(:post_number)

      Post
        .where(topic_id: topic.id)
        .joins(:user)
        .where("post_number in (?)", post_numbers)
        .order(:post_number)
    end

    def delete_cached_summaries!
      AiSummary.where(target: topic).destroy_all
    end

    def use_cached?(skip_age_check)
      can_summarize = Guardian.new(user).can_request_summary?

      existing_summary &&
        !(
          can_summarize && new_targets? &&
            (skip_age_check || existing_summary.created_at < 1.hour.ago)
        )
    end

    def new_targets?
      existing_summary&.original_content_sha != summary_sha
    end

    def cache_summary(result)
      post_numbers = summary_targets_data.map(&:first)

      cached_summary =
        AiSummary.create!(
          target: topic,
          algorithm: strategy.display_name,
          content_range: (post_numbers.first..post_numbers.last),
          summarized_text: result[:summary],
          original_content_sha: summary_sha,
        )

      cached_summary
    end

    def build_sha(ids)
      Digest::SHA256.hexdigest(ids.join)
    end
  end
end
