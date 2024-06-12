# frozen_string_literal: true

class UpgradePgvector070 < ActiveRecord::Migration[7.0]
  def up
    DB.exec("ALTER EXTENSION \"vector\" UPDATE TO '0.7.0';")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
