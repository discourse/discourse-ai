# frozen_string_literal: true

begin
  LlmModel.seed_srv_backed_model
rescue PG::UndefinedColumn => e
  # If this code runs before migrations, an attribute might be missing.
  Rails.logger.warn("Failed to seed SRV-Backed LLM: #{e.meesage}")
end
