module ClientsHelper
  # A client's tabs, with their counts and plugins' panels (clients/_record_tab).
  def client_record_tabs(client)
    [
      record_tab("works", term(:work, count: 2), count: client.works.count),
      record_tab("tasks", term(:task, count: 2), count: client.tasks.open.count),
      record_tab("notes", "Notes", count: client.notes.count),
      record_tab("documents", "Documents", count: client.documents.count)
    ] + plugin_record_tabs(:client_panel)
  end
end
