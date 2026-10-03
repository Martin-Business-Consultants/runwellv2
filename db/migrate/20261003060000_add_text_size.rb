class AddTextSize < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :text_size, :string, null: false, default: "default"
    add_column :users, :text_size, :string
  end
end
