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

  # The clients table's status menu, on the page once (TasksHelper#page_template): each row's badge
  # opens it beside itself, and the picker controller points its form at that client.
  def client_status_menu
    return if @client_status_menu_rendered

    @client_status_menu_rendered = true
    items = Client::STATUSES.map do |status|
      label = safe_join([ tag.span(status.humanize, class: "picker-menu__label"), tag.span(status_tag(status, highlight: status == "active"), hidden: true, data: { picker_part: "tag" }),
        icon_tag("check", class: "picker-menu__check") ])
      { label: label, value: status, data: { picker_value: status } }
    end
    page_template do
      ui(:menu, id: "client-status-menu", label: "Status", class: "picker-menu", items: items) +
        tag.template(id: "client-status-form") do
          form_with(url: "#", method: :patch, authenticity_token: false, class: "picker-form") { hidden_field_tag("client[status]", nil, id: nil, data: { picker_field: true }) + hidden_field_tag(:from_list, "1", id: nil) }
        end
    end
  end
end
