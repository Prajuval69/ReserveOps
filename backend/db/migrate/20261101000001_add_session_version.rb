# frozen_string_literal: true

class AddSessionVersion < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :session_version, :integer, null: false, default: 0
  end
end
