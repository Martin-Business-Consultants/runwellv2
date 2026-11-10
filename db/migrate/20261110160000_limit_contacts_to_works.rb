# A contact may be limited to some of their client's work in the portal (users.portal_limited),
# the pieces of work being contact_works. Without the switch they see everything shared, as before.
class LimitContactsToWorks < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :portal_limited, :boolean, default: false, null: false

    create_table :contact_works do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :work, null: false, foreign_key: { on_delete: :cascade }
      t.index %i[user_id work_id], unique: true
    end
  end
end
