# frozen_string_literal: true

module DiscourseAi
  class TopicSummarization
    def self.summarize(topic, user, opts = {}, &on_partial_blk)
      strategy =
        DiscourseAi::Summarization::Strategies::FoldContent.new(SiteSetting.ai_summarization_model)
      new(strategy).summarize(topic, user, opts, &on_partial_blk)
    end

    def initialize(strategy)
      @strategy = strategy
    end

    def summarize(topic, user, opts = {}, &on_partial_blk)
      existing_summary = AiSummary.find_by(target: topic)

      # Existing summary shouldn't be nil in this scenario because the controller checks its existence.
      return if !user && !existing_summary

      targets_data = summary_targets(topic).pluck(:post_number, :raw, :username)

      current_topic_sha = build_sha(targets_data.map(&:first))
      can_summarize = Guardian.new(user).can_request_summary?

      if use_cached?(existing_summary, can_summarize, current_topic_sha, !!opts[:skip_age_check])
        # It's important that we signal a cached summary is outdated
        existing_summary.mark_as_outdated if new_targets?(existing_summary, current_topic_sha)

        return existing_summary
      end

      delete_cached_summaries_of(topic) if existing_summary

      content = {
        resource_path: "#{Discourse.base_path}/t/-/#{topic.id}",
        content_title: topic.title,
        contents: [],
      }

      targets_data.map do |(pn, raw, username)|
        raw_text = raw

        if pn == 1 && topic.topic_embed&.embed_content_cache.present?
          raw_text = topic.topic_embed&.embed_content_cache
        end

        content[:contents] << { poster: username, id: pn, text: raw_text }
      end

      summarization_result = strategy.summarize(content, user, &on_partial_blk)

      cache_summary(summarization_result, targets_data.map(&:first), topic)
    end

    def summary_targets(topic)
      topic.has_summary? ? best_replies(topic) : pick_selection(topic)
    end

    private

    attr_reader :strategy

    def best_replies(topic)
      Post
        .summary(topic.id)
        .where("post_type = ?", Post.types[:regular])
        .where("NOT hidden")
        .joins(:user)
        .order(:post_number)
    end

    def pick_selection(topic)
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

    def delete_cached_summaries_of(topic)
      AiSummary.where(target: topic).destroy_all
    end

    # For users without permissions to generate a summary or fresh summaries, we return what we have cached.
    def use_cached?(existing_summary, can_summarize, current_sha, skip_age_check)
      existing_summary &&
        !(
          can_summarize && new_targets?(existing_summary, current_sha) &&
            (skip_age_check || existing_summary.created_at < 1.hour.ago)
        )
    end

    def new_targets?(summary, current_sha)
      summary.original_content_sha != current_sha
    end

    def cache_summary(result, post_numbers, topic)
      cached_summary =
        AiSummary.create!(
          target: topic,
          algorithm: strategy.display_name,
          content_range: (post_numbers.first..post_numbers.last),
          summarized_text: result[:summary],
          original_content_sha: build_sha(post_numbers),
        )

      cached_summary
    end

    def build_sha(ids)
      Digest::SHA256.hexdigest(ids.join)
    end
  end
end
