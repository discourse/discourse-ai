# frozen_string_literal: true
class CopyAiImageCaptionModelToPersonaDefault < ActiveRecord::Migration[7.2]
  def up
    ai_helper_image_caption_model =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'ai_helper_image_caption_model'",
      ).first

    if ai_helper_image_caption_model.present? &&
         ai_helper_image_caption_model.start_with?("custom:")
      # Extract the model ID from the setting value (e.g., "custom:1" -> "1")
      model_id = ai_helper_image_caption_model.split(":").last

      # Update the helper personas with the extracted model ID
      execute(<<~SQL)
        UPDATE ai_personas
        SET default_llm_id = #{model_id}
        WHERE id IN (-26) AND default_llm_id IS NULL
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
