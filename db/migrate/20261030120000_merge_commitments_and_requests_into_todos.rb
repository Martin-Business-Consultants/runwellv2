# Commitments and requests become work. A todo may belong to a client without an engagement, and
# keeps who asked for it and how (contact, source, an unmatched sender). Open requests become
# unassigned work (which is what a request now is) and open commitments of ours become work owned
# by whoever owned them, with their notes, documents, mentions, events and search entries moved
# across. Triaged requests and resolved or client commitments stay where they are: the tables are
# left for a later release to drop, once no install reads them.
class MergeCommitmentsAndRequestsIntoTodos < ActiveRecord::Migration[8.1]
  class Todo < ActiveRecord::Base
    self.table_name = "todos"
  end

  class Assignment < ActiveRecord::Base
    self.table_name = "assignments"
  end

  class Request < ActiveRecord::Base
    self.table_name = "requests"
  end

  class Commitment < ActiveRecord::Base
    self.table_name = "commitments"
  end

  POINTERS = { "notes" => "subject", "documents" => "documentable", "events" => "subject",
               "mentions" => "source", "notifications" => "source", "custom_values" => "subject" }.freeze

  def up
    add_column :todos, :client_id, :integer
    add_column :todos, :contact_id, :integer
    add_column :todos, :source, :string, default: "app", null: false
    add_column :todos, :sender_name, :string
    add_column :todos, :sender_email, :string
    add_index :todos, :client_id
    add_index :todos, :contact_id
    change_column_null :todos, :engagement_id, true

    execute "UPDATE todos SET client_id = (SELECT client_id FROM engagements WHERE engagements.id = todos.engagement_id)"

    Request.where(status: "open").find_each do |request|
      todo = create_todo(engagement_id: nil, client_id: request.client_id, contact_id: request.contact_id,
                         title: request.subject, description: request.body, source: request.source,
                         sender_name: request.sender_name, sender_email: request.sender_email,
                         created_at: request.received_at || request.created_at)
      repoint("Request", request.id, todo.id)
    end

    Commitment.where(resolution: nil, owner_kind: "us").find_each do |commitment|
      todo = create_todo(engagement_id: commitment.engagement_id, client_id: commitment.client_id,
                         title: commitment.description, owner_id: commitment.user_id, due_on: commitment.due_on,
                         source: "app", created_at: commitment.created_at)
      if commitment.user_id
        Assignment.create!(todo_id: todo.id, user_id: commitment.user_id, created_at: Time.current, updated_at: Time.current)
      end
      repoint("Commitment", commitment.id, todo.id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def create_todo(engagement_id:, created_at:, **attributes)
    position = Todo.where(engagement_id: engagement_id, status: "planned").maximum(:position).to_i + 1
    board_position = Todo.where(status: "planned").maximum(:board_position).to_i + 1
    Todo.create!(attributes.merge(engagement_id: engagement_id, status: "planned", client_visible: true,
                                  position: position, board_position: board_position,
                                  created_at: created_at, updated_at: Time.current))
  end

  def repoint(type, from_id, to_id)
    POINTERS.each do |table, name|
      next unless table_exists?(table)

      execute <<~SQL
        UPDATE #{table} SET #{name}_id = #{to_id.to_i}, #{name}_type = 'Todo'
        WHERE #{name}_type = '#{type}' AND #{name}_id = #{from_id.to_i}
      SQL
    end
    execute "DELETE FROM searchable_documents WHERE searchable_type = '#{type}' AND searchable_id = '#{from_id.to_i}'" if table_exists?(:searchable_documents)
  end
end
