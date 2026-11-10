# The portal as a two-way channel: which of a task's discussion a contact has read
# (discussion_reads), whether they want the portal's emails (users.portal_emails), and
# notifications whose creator is unknown (a request emailed by someone we don't have on file).
class PortalTwoWay < ActiveRecord::Migration[8.1]
  def change
    create_table :discussion_reads do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :task, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :read_at, null: false
      t.index %i[user_id task_id], unique: true
    end

    add_column :users, :portal_emails, :boolean, default: true, null: false
    # Nothing points at notifications, so SQLite's copy-and-drop takes nothing with it.
    change_column_null :notifications, :creator_id, true
  end
end
