class CreateAiChats < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_chats, id: :bigint do |t|
      t.references :ruby_llm_model, null: false, foreign_key: { to_table: :ruby_llm_models }, type: :bigint
      t.boolean :cancelled, null: false, default: false
      # Runwell's: whose chat it is, what it's about, and what for (the Ask panel or a suggestion).
      t.references :user, foreign_key: true
      t.references :subject, polymorphic: true
      t.string :purpose, null: false, default: "ask"
      t.string :title
      t.datetime :replying_since
      t.timestamps
    end
    add_index :ai_chats, %i[user_id purpose updated_at]
  end
end
