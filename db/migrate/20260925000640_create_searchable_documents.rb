class CreateSearchableDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :searchable_documents do |t|
      t.string :searchable_type, null: false
      t.string :searchable_id, null: false
      t.string :client_id
      t.datetime :created_at
    end
    add_index :searchable_documents, [ :searchable_type, :searchable_id ], unique: true

    create_virtual_table :searchable_documents_fts, :fts5, [ "title", "content", "tokenize='porter'" ]
  end
end
