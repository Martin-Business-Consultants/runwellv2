# 7.0: a client's contacts are users with the client role (Contact is that slice of users), so
# there's one kind of person, one Users page and one owner for a token or a session. Each contact
# becomes a user: role "client", its client, title (what was contacts.role), phone, portal_access,
# can_approve, deactivated when it was archived, and legacy_contact_id so a plugin can repoint its
# own rows. Tasks' contact_id, tokens and OAuth grants move to the new users; portal sessions end
# (clients sign in again by link). contacts and portal_sessions are left, unread, for a later
# release to drop.
#
# users.email_address becomes optional (a contact may have only a phone), which SQLite does by
# copying the table: this runs outside a transaction with foreign keys off, so nothing cascades
# (see AGENTS.md, Releases and updates).
class FoldContactsIntoUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_reference :users, :client, foreign_key: true unless column_exists?(:users, :client_id)
    add_column :users, :title, :string unless column_exists?(:users, :title)
    add_column :users, :phone, :string unless column_exists?(:users, :phone)
    add_column :users, :portal_access, :boolean, default: false, null: false unless column_exists?(:users, :portal_access)
    add_column :users, :can_approve, :boolean, default: false, null: false unless column_exists?(:users, :can_approve)
    add_column :users, :legacy_contact_id, :integer unless column_exists?(:users, :legacy_contact_id)
    add_index :users, :legacy_contact_id, unique: true unless index_exists?(:users, :legacy_contact_id)

    without_foreign_keys { change_column_null :users, :email_address, true }

    transaction do
      execute <<~SQL
        INSERT INTO users (name, email_address, password_digest, role, client_id, title, phone, portal_access, can_approve,
                           deactivated_at, legacy_contact_id, created_at, updated_at)
        SELECT contacts.name,
               CASE WHEN contacts.email IS NULL OR contacts.email = ''
                      OR EXISTS (SELECT 1 FROM users taken WHERE taken.email_address = lower(contacts.email))
                      OR EXISTS (SELECT 1 FROM contacts earlier WHERE lower(earlier.email) = lower(contacts.email) AND earlier.id < contacts.id)
                    THEN NULL ELSE lower(contacts.email) END,
               '!', 'client', contacts.client_id, contacts.role, contacts.phone, contacts.portal_access, contacts.can_approve,
               contacts.archived_at, contacts.id, contacts.created_at, contacts.updated_at
        FROM contacts
        WHERE NOT EXISTS (SELECT 1 FROM users done WHERE done.legacy_contact_id = contacts.id)
      SQL

      repoint = "(SELECT users.id FROM users WHERE users.legacy_contact_id = %s.contact_id)"
      execute "UPDATE tasks SET contact_id = #{repoint % "tasks"} WHERE contact_id IS NOT NULL AND contact_id IN (SELECT legacy_contact_id FROM users WHERE legacy_contact_id IS NOT NULL) AND NOT EXISTS (SELECT 1 FROM users WHERE users.id = tasks.contact_id AND users.role = 'client')"
      %w[access_tokens oauth_grants].each do |table|
        execute "UPDATE #{table} SET user_id = #{repoint % table}, contact_id = NULL WHERE contact_id IS NOT NULL"
      end
      # Clients never sign in with a password: each gets a random one nobody knows (bcrypt's
      # lowest cost, since it's never checked against anything typed).
      select_values("SELECT id FROM users WHERE password_digest = '!'").each do |id|
        digest = BCrypt::Password.create(SecureRandom.base58(32), cost: BCrypt::Engine::MIN_COST)
        execute "UPDATE users SET password_digest = #{connection.quote(digest)} WHERE id = #{id.to_i}"
      end
      execute "DELETE FROM portal_sessions"
      # Their search entries follow them (Contact keeps its type name, Contact.polymorphic_name). In
      # two passes, through negative ids: (type, id) is unique, and an old contact id can be another
      # contact's new user id. Entries for a contact that's gone are dropped.
      if table_exists?(:searchable_documents)
        execute "UPDATE searchable_documents SET searchable_id = -searchable_id WHERE searchable_type = 'Contact' AND searchable_id > 0"
        execute "UPDATE searchable_documents SET searchable_id = (SELECT users.id FROM users WHERE users.legacy_contact_id = -searchable_documents.searchable_id) WHERE searchable_type = 'Contact' AND searchable_id < 0 AND EXISTS (SELECT 1 FROM users WHERE users.legacy_contact_id = -searchable_documents.searchable_id)"
        execute "DELETE FROM searchable_documents WHERE searchable_type = 'Contact' AND searchable_id < 0"
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Restore the backup taken before the update instead."
  end

  private
    def without_foreign_keys
      execute "PRAGMA foreign_keys = OFF"
      yield
    ensure
      execute "PRAGMA foreign_keys = ON"
    end
end
