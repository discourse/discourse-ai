# frozen_string_literal: true

# name: discourse-ai
# about: Enables integration between AI modules and features in Discourse
# meta_topic_id: 259214
# version: 0.0.1
# authors: Discourse
# url: https://meta.discourse.org/t/discourse-ai/259214
# required_version: 2.7.0

gem "tokenizers", "0.4.2"
gem "tiktoken_ruby", "0.0.5"

enabled_site_setting :discourse_ai_enabled

register_asset "stylesheets/modules/ai-helper/common/ai-helper.scss"

register_asset "stylesheets/modules/ai-bot/common/bot-replies.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-persona.scss"

register_asset "stylesheets/modules/embeddings/common/semantic-related-topics.scss"
register_asset "stylesheets/modules/embeddings/common/semantic-search.scss"

register_asset "stylesheets/modules/sentiment/common/dashboard.scss"
register_asset "stylesheets/modules/sentiment/desktop/dashboard.scss", :desktop
register_asset "stylesheets/modules/sentiment/mobile/dashboard.scss", :mobile

module ::DiscourseAi
  PLUGIN_NAME = "discourse-ai"
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: ::DiscourseAi)

require_relative "lib/engine"

register_svg_icon "smile"
register_svg_icon "frown"
register_svg_icon "meh"

after_initialize do
  # do not autoload this cause we may have no namespace
  require_relative "discourse_automation/llm_triage"
  require_relative "discourse_automation/llm_report"

  add_admin_route "discourse_ai.title", "discourse-ai"

  [
    DiscourseAi::Embeddings::EntryPoint.new,
    DiscourseAi::Nsfw::EntryPoint.new,
    DiscourseAi::Toxicity::EntryPoint.new,
    DiscourseAi::Sentiment::EntryPoint.new,
    DiscourseAi::AiHelper::EntryPoint.new,
    DiscourseAi::Summarization::EntryPoint.new,
    DiscourseAi::AiBot::EntryPoint.new,
  ].each { |a_module| a_module.inject_into(self) }

  register_reviewable_type ReviewableAiChatMessage
  register_reviewable_type ReviewableAiPost

  on(:reviewable_transitioned_to) do |new_status, reviewable|
    ModelAccuracy.adjust_model_accuracy(new_status, reviewable)
  end

  require_dependency "user_summary"
  class ::UserSummary
    def sentiment
      neutral, positive, negative = DB.query_single(<<~SQL, user_id: @user.id)
        WITH last_interactions_classified AS (
          SELECT
            1 AS total,
            CASE WHEN (classification::jsonb->'positive')::integer >= 60 THEN 1 ELSE 0 END AS positive,
            CASE WHEN (classification::jsonb->'negative')::integer >= 60 THEN 1 ELSE 0 END AS negative
          FROM
            classification_results AS cr
          INNER JOIN
            posts AS p ON
            p.id = cr.target_id AND
            cr.target_type = 'Post'
          INNER JOIN topics AS t ON
            t.id = p.topic_id
          INNER JOIN categories AS c ON
            c.id = t.category_id
          WHERE
            model_used = 'sentiment' AND
            p.user_id = :user_id
          ORDER BY
            p.created_at DESC
          LIMIT
            100
        )
        SELECT
          SUM(total) - SUM(positive) - SUM(negative) AS neutral,
          SUM(positive) AS positive,
          SUM(negative) AS negative
        FROM
          last_interactions_classified
      SQL

      neutral = neutral || 0
      positive = positive || 0
      negative = negative || 0

      return nil if neutral + positive + negative < 5

      case [neutral / 5, positive, negative].max
      when positive
        :positive
      when negative
        :negative
      else
        :neutral
      end
    end
  end

  require_dependency "user_summary_serializer"
  class ::UserSummarySerializer
    attributes :sentiment

    def sentiment
      object.sentiment.to_s
    end
  end

  if Rails.env.test?
    require_relative "spec/support/openai_completions_inference_stubs"
    require_relative "spec/support/anthropic_completion_stubs"
    require_relative "spec/support/stable_diffusion_stubs"
    require_relative "spec/support/embeddings_generation_stubs"
  end
end
