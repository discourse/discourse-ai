# frozen_string_literal: true

class UpgradePgvector070 < ActiveRecord::Migration[7.0]
  def up
    minimum_target_version = "0.7.0"
    installed_version =
      DB.query_single("SELECT extversion FROM pg_extension WHERE extname = 'vector';").first

    if GEM::Version.new(installed_version) < GEM::Version.new(minimum_target_version)
      DB.exec("ALTER EXTENSION vector UPDATE TO '0.7.0';")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
