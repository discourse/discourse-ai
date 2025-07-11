# frozen_string_literal: true
class CopyAiSummarizationModelToPersonaDefault < ActiveRecord::Migration[7.2]
  def up
    ai_summarization_model =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'ai_summarization_model'").first

    if ai_summarization_model.present? && ai_summarization_model.start_with?("custom:")
      # Extract the model ID from the setting value (e.g., "custom:-5" -> "-5")
      model_id = ai_summarization_model.split(":").last

      # Update the summarization personas (IDs -11 and -12) with the extracted model ID
      execute(<<~SQL)
        UPDATE ai_personas
        SET default_llm_id = #{model_id}
        WHERE id IN (-11, -12) AND default_llm_id IS NULL
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
