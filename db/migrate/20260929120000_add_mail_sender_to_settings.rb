# Who the install's mail comes from, set in Settings > Email rather than only in MAIL_FROM.
# The Outsend plugin kept its own sender until now; one it saved becomes the install's, so
# nothing changes for an install that set it there.
class AddMailSenderToSettings < ActiveRecord::Migration[8.1]
  def up
    add_column :settings, :mail_from_name, :string
    add_column :settings, :mail_from_email, :string

    if table_exists?(:outsend_connections) && column_exists?(:outsend_connections, :from_email)
      execute <<~SQL
        UPDATE settings SET
          mail_from_name = (SELECT from_name FROM outsend_connections LIMIT 1),
          mail_from_email = (SELECT from_email FROM outsend_connections LIMIT 1)
      SQL
    end
  end

  def down
    remove_column :settings, :mail_from_name
    remove_column :settings, :mail_from_email
  end
end
