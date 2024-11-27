# frozen_string_literal: true

class AiUsageSerializer < ApplicationSerializer
  attributes :data, :features, :models, :summary

  def data
    object.tokens_by_period.map {|key, value| [key, value]}
  end

  def features
    object.feature_breakdown.as_json(only: %i[feature_name usage_count total_tokens])
  end

  def models
    object.model_breakdown.as_json(only: %i[llm usage_count total_tokens])
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
