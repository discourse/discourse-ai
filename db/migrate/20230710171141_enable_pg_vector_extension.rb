# frozen_string_literal: true

class EnablePgVectorExtension < ActiveRecord::Migration[7.0]
  def change
    enable_extension :vector
  end
end
