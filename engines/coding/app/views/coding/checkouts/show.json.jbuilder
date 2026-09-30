workspace = @workspace
json.summary workspace.repositories.any? ? "#{@todo.title}: #{workspace.repositories.map(&:name).to_sentence}, branch #{workspace.branch_name}" : "#{@todo.title}: no repository linked on the todo, its engagement or its client"
json.todo do
  json.partial! "todos/todo", todo: @todo
  json.description agent_text(@todo.description)
end
json.branch workspace.branch_name
json.repositories workspace.repositories do |repository|
  json.merge! agent_ref(repository).except("url")
  json.extract! repository, :url, :default_branch, :path, :staging_url, :production_url
  json.web_url repository.web_url
  json.inherited_from agent_ref(repository.linkable) unless repository.linkable == @todo
  json.branch workspace.branch_for(repository)
  json.commands workspace.clone_commands(repository)
  json.setup_notes agent_text(repository.setup_notes)
end
json.agreed_scope do
  json.approved workspace.agreed.present?
  json.items workspace.agreed_items.map { { description: it.description, this_todo: it == @todo.scope_item } }
  json.as_the_client_saw_it workspace.agreed
  json.draft_items(workspace.draft&.scope_items&.map(&:description) || [])
end
json.scope_item agent_ref(@todo.scope_item)
json.commitments workspace.commitments, partial: "commitments/commitment", as: :commitment
json.notes workspace.notes, partial: "notes/note", as: :note
json.documents workspace.documents, partial: "documents/document", as: :document
