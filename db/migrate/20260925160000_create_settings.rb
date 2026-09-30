class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.json :terminology, null: false, default: {}
      t.json :disabled_plugins, null: false, default: []
      t.timestamps
    end
  end
end
