# A client's own order of what matters to them, set by dragging in the portal: their pieces of work,
# each work's sections, and the tasks shared with them. Kept apart from the team's working order
# (positions), so neither undoes the other. Blank until the client orders them.
class AddClientPriority < ActiveRecord::Migration[8.1]
  def change
    add_column :works, :client_priority, :integer
    add_column :scope_items, :client_priority, :integer
    add_column :tasks, :client_priority, :integer
  end
end
