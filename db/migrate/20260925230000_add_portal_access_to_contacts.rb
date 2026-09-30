# Portal sign-in becomes a switch per contact, off for new contacts. Contacts who could
# already sign in (an email on file) keep their access.
class AddPortalAccessToContacts < ActiveRecord::Migration[8.1]
  def up
    add_column :contacts, :portal_access, :boolean, default: false, null: false
    execute "UPDATE contacts SET portal_access = TRUE WHERE email IS NOT NULL AND archived_at IS NULL"
  end

  def down
    remove_column :contacts, :portal_access
  end
end
