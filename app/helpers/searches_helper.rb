module SearchesHelper
  # Where a result opens: the record's own page, or the page it lives on.
  def search_result_path(record)
    case record
    when Contact then client_path(record.client)
    when Todo then todo_path(record)
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

  # Results in groups by kind, the kinds in the order of their best match: [[label, records], …].
  def search_result_groups(results)
    Array(results).group_by { search_result_kind(it) }.to_a
  end

  def search_result_kind(record)
    case record
    when Client then term(:client, count: 2)
    when Engagement then term(:engagement, count: 2)
    when Todo then term(:work)
    when ScopeItem then term(:scope_item, count: 2)
    else record.model_name.human.pluralize
    end
  end

  SEARCH_ICONS = { "Client" => "everyone", "Contact" => "person", "Engagement" => "clipboard", "Todo" => "check-circle",
    "ScopeItem" => "board", "Note" => "comment", "Document" => "attachment" }.freeze

  def search_result_icon(record) = SEARCH_ICONS.fetch(record.class.name, "search")

  # The clients of every result on the page, looked up once rather than per result.
  def search_client_names
    @search_client_names ||= Client.where(id: Array(@search&.results).filter_map { it.try(:search_client_id) }).pluck(:id, :name).to_h
  end
end
