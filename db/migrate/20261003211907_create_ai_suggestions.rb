# What the in-app AI suggested on a record (triage, scope, tasks, a summary…): its answer, whether
# the person used it, and the chat it came from (whose usage says what it cost).
class CreateAiSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_suggestions do |t|
      t.references :user, foreign_key: true
      t.references :subject, polymorphic: true
      t.references :ai_chat, foreign_key: true
      t.string :kind, null: false
      t.string :state, null: false, default: "working"
      t.json :payload
      t.string :error
      t.timestamps
    end
    add_index :ai_suggestions, %i[kind subject_type subject_id created_at]
  end
end
