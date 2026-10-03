module SearchesHelper
  # Where a result opens: the record's own page, or the page it lives on.
  def search_result_path(record)
    case record
    when Contact then client_path(record.client)
    when Todo then todo_path(record)
    when ScopeItem then scope_item_path(record)
    when Commitment then record.engagement ? engagement_path(record.engagement) : client_path(record.client)
    when Note then search_result_path(record.subject)
    when Document then search_result_path(record.documentable)
    when AgreementVersion then engagement_path(record.engagement)
    else polymorphic_path(record)
    end
  end

  def search_result_context(record)
    client_name = search_client_names[record.search_client_id] unless record.is_a?(Client)
    [ record.model_name.human, client_name ].compact.join(" · ")
  end

  # The clients of every result on the page, looked up once rather than per result.
  def search_client_names
    @search_client_names ||= Client.where(id: Array(@search&.results).filter_map { it.try(:search_client_id) }).pluck(:id, :name).to_h
  end
end
