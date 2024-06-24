# frozen_string_literal: true
class LlmModelCustomParams < ActiveRecord::Migration[7.1]
  def change
    add_column :llm_models, :provider_params, :jsonb
  end
end
