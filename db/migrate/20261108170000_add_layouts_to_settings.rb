# Template mode: how an install arranges each kind of record's fields (RecordLayout), one row.
class AddLayoutsToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :layouts, :json, default: {}, null: false
  end
end
