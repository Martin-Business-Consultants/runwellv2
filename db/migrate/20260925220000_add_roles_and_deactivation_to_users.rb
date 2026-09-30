# Roles become owner / manager / member (staff were members), and people are deactivated
# rather than deleted so their names stay on their history.
class AddRolesAndDeactivationToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :deactivated_at, :datetime
    change_column_default :users, :role, from: "staff", to: "member"
    execute "UPDATE users SET role = 'member' WHERE role = 'staff'"
  end

  def down
    execute "UPDATE users SET role = 'staff' WHERE role IN ('member', 'manager')"
    change_column_default :users, :role, from: "member", to: "staff"
    remove_column :users, :deactivated_at
  end
end
