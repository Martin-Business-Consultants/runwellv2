# What MergeCommitmentsAndRequestsIntoTodos left behind, so no history points at a commitment or a
# request any more: our resolved commitments become done work; a client's promises (which are gone)
# hand their history to their engagement, else their client; a dismissed request becomes done work
# (the reason in its description); a promoted one hands its notes, documents and history to what it
# became. The old rows stay in their tables for a later release to drop.
class RehomeClosedCommitmentsAndRequests < ActiveRecord::Migration[8.1]
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

  class AgreementVersion < ActiveRecord::Base
    self.table_name = "agreement_versions"
  end

  POINTERS = { "notes" => "subject", "documents" => "documentable", "events" => "subject",
               "mentions" => "source", "notifications" => "source", "custom_values" => "subject" }.freeze

  def up
    Commitment.where.not(resolution: nil).where(owner_kind: "us").find_each do |commitment|
      todo = create_done_todo(engagement_id: commitment.engagement_id, client_id: commitment.client_id, title: commitment.description,
                              description: commitment.resolution_note.presence && "<p>#{ERB::Util.html_escape(commitment.resolution_note)}</p>",
                              owner_id: commitment.user_id, due_on: commitment.due_on, created_at: commitment.created_at,
                              completed_at: commitment.resolved_at || commitment.updated_at)
      Assignment.create!(todo_id: todo.id, user_id: commitment.user_id, created_at: Time.current, updated_at: Time.current) if commitment.user_id
      repoint("Commitment", commitment.id, "Todo", todo.id)
    end

    Commitment.where(owner_kind: "client").find_each do |commitment|
      commitment.engagement_id ? repoint("Commitment", commitment.id, "Engagement", commitment.engagement_id)
                               : repoint("Commitment", commitment.id, "Client", commitment.client_id)
    end

    Request.where(status: "dismissed").find_each do |request|
      reason = "<p>Dismissed#{": #{ERB::Util.html_escape(request.dismissed_reason)}" if request.dismissed_reason.present?}</p>"
      todo = create_done_todo(engagement_id: nil, client_id: request.client_id, contact_id: request.contact_id, title: request.subject,
                              description: [ request.body, reason ].compact.join, source: request.source,
                              sender_name: request.sender_name, sender_email: request.sender_email,
                              created_at: request.received_at || request.created_at, completed_at: request.triaged_at || request.updated_at)
      repoint("Request", request.id, "Todo", todo.id)
    end

    Request.where(status: "promoted").find_each do |request|
      type, id = promoted_home(request)
      type ? repoint("Request", request.id, type, id) : forget("Request", request.id)
    end

    # Anything else still naming one (a commitment of ours with no row left, say) has no home.
    %w[Commitment Request].each { |type| forget(type, nil) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def promoted_home(request)
    case request.promoted_type
    when "Todo", "Engagement" then [ request.promoted_type, request.promoted_id ]
    when "AgreementVersion"
      engagement_id = AgreementVersion.where(id: request.promoted_id).pick(:engagement_id)
      [ "Engagement", engagement_id ] if engagement_id
    when "Commitment"
      commitment = Commitment.find_by(id: request.promoted_id)
      if commitment&.engagement_id then [ "Engagement", commitment.engagement_id ]
      elsif commitment then [ "Client", commitment.client_id ]
      end
    end || (request.client_id && [ "Client", request.client_id ])
  end

  def create_done_todo(engagement_id:, created_at:, completed_at:, **attributes)
    position = Todo.where(engagement_id: engagement_id, status: "done").maximum(:position).to_i + 1
    board_position = Todo.where(status: "done").maximum(:board_position).to_i + 1
    Todo.create!(attributes.merge(engagement_id: engagement_id, status: "done", client_visible: false, source: attributes[:source] || "app",
                                  position: position, board_position: board_position, completed_at: completed_at,
                                  created_at: created_at, updated_at: Time.current))
  end

  def repoint(type, from_id, to_type, to_id)
    POINTERS.each do |table, name|
      next unless table_exists?(table)

      execute <<~SQL
        UPDATE #{table} SET #{name}_id = #{to_id.to_i}, #{name}_type = #{connection.quote(to_type)}
        WHERE #{name}_type = '#{type}' AND #{name}_id = #{from_id.to_i}
      SQL
    end
    forget_search(type, from_id)
  end

  # Rows that would point at nothing: a request with no client and nothing it became, or anything
  # left over. Their notes and documents go with them; the request itself stays in its table.
  def forget(type, id)
    POINTERS.each do |table, name|
      next unless table_exists?(table)

      execute "DELETE FROM #{table} WHERE #{name}_type = '#{type}'#{" AND #{name}_id = #{id.to_i}" if id}"
    end
    forget_search(type, id)
  end

  def forget_search(type, id)
    return unless table_exists?(:searchable_documents)

    execute "DELETE FROM searchable_documents WHERE searchable_type = '#{type}'#{" AND searchable_id = '#{id.to_i}'" if id}"
  end
end
