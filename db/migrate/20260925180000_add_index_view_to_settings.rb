class AddIndexViewToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :index_view, :string, null: false, default: "cards"
  end
end
