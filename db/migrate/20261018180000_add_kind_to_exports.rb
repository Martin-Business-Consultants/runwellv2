# An export is the readable kind (every table as JSON and CSV, secrets left out) or a backup (the
# database itself and every stored file, to restore or move to Runwell Go).
class AddKindToExports < ActiveRecord::Migration[8.1]
  def change
    add_column :exports, :kind, :string, default: "data", null: false
  end
end
