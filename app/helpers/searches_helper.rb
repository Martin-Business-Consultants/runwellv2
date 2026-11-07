module SearchesHelper
  # Where a result opens: the record's own page, or the page it lives on.
  def search_result_path(record)
    case record
    when Contact then client_path(record.client)
    when Task then task_path(record)
    when ScopeItem then scope_item_path(record)
    when Note then search_result_path(record.subject)
    when Document then search_result_path(record.documentable)
    else polymorphic_path(record)
    end
  end

  # The client a result belongs to, on the right of its row (its group names its kind).
  def search_result_context(record)
    search_client_names[record.search_client_id] unless record.is_a?(Client)
  end

  # Results by kind, the kinds in a fixed order (clients, work, tasks, then people, then the
  # rest), each kind's results in order of relevance. people: the team members who match.
  SEARCH_PRIORITY = %w[Client Work Task User Contact ScopeItem Note Document].freeze

  def search_result_groups(results, people: [])
    records = Array(results) + Array(people)
    records.group_by { it.class.name }
      .sort_by { |type, _| SEARCH_PRIORITY.index(type) || SEARCH_PRIORITY.size }
      .map { |_type, group| [ search_result_kind(group.first), group ] }
  end

  def search_result_kind(record)
    case record
    when Client then term(:client, count: 2)
    when Work then term(:work, count: 2)
    when Task then term(:task, count: 2)
    when ScopeItem then term(:scope_item, count: 2)
    when User then "People"
    else record.model_name.human.pluralize
    end
  end

  # A result's link: it closes the bar, and a task opens in the side panel (side_panel_link_to).
  def search_result_link_to(result, **options, &block)
    if result.is_a?(Task)
      side_panel_link_to(result, data: { action: "bar#reset" }, **options, &block)
    else
      link_to(search_result_path(result), data: { turbo_frame: "_top", action: "bar#reset" }, **options, &block)
    end
  end

  SEARCH_ICONS = { "Client" => "everyone", "Contact" => "person", "Work" => "clipboard", "Task" => "check-circle",
    "ScopeItem" => "board", "Note" => "comment", "Document" => "attachment" }.freeze

  def search_result_icon(record) = SEARCH_ICONS.fetch(record.class.name, "search")

  # The clients of every result on the page, looked up once rather than per result.
  def search_client_names
    @search_client_names ||= Client.where(id: Array(@search&.results).filter_map { it.try(:search_client_id) }).pluck(:id, :name).to_h
  end
end
