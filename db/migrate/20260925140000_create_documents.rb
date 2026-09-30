class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :documentable, polymorphic: true, null: false
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.boolean :client_visible, null: false, default: false
      t.timestamps
    end
  end
end
