# frozen_string_literal: true
class CopyTranslationModelToPersona < ActiveRecord::Migration[7.2]
  def up
    ai_translation_model =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'ai_translation_model'").first

    if ai_translation_model.present? && ai_translation_model.start_with?("custom:")
      # Extract the model ID from the setting value (e.g., "custom:-5" -> "-5")
      model_id = ai_translation_model.split(":").last

      # Update the translation personas (IDs -27, -28, -29, -30) with the extracted model ID
      execute(<<~SQL)
        UPDATE ai_personas
        SET default_llm_id = #{model_id}
        WHERE id IN (-27, -28, -29, -30) AND default_llm_id IS NULL
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
