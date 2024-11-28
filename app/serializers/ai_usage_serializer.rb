# frozen_string_literal: true

class AiUsageSerializer < ApplicationSerializer
  attributes :data, :features, :models, :users, :summary

  def data
    object.tokens_by_period.as_json(
      only: %i[period total_tokens total_cached_tokens total_request_tokens total_response_tokens],
    )
  end

  def features
    object.feature_breakdown.as_json(
      only: %i[
        feature_name
        usage_count
        total_tokens
        total_cached_tokens
        total_request_tokens
        total_response_tokens
      ],
    )
  end

  def models
    object.model_breakdown.as_json(
      only: %i[
        llm
        usage_count
        total_tokens
        total_cached_tokens
        total_request_tokens
        total_response_tokens
      ],
    )
  end

  def users
    object.user_breakdown.as_json(
      only: %i[
        username
        usage_count
        total_tokens
        total_cached_tokens
        total_request_tokens
        total_response_tokens
      ],
    )
  end

  def summary
    {
      total_tokens: object.total_tokens,
      date_range: {
        start: object.start_date,
        end: object.end_date,
      },
    }
  end
end
