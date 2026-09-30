# Outsend, as a plugin: one row holding the API key and what happened to mail sent through it.
class CreateOutsend < ActiveRecord::Migration[8.1]
  def change
    create_table :outsend_connections do |t|
      t.text :api_key
      t.datetime :last_delivered_at
      t.integer :delivered_count, null: false, default: 0
      t.text :last_error
      t.datetime :last_error_at
      t.timestamps
    end
  end
end
