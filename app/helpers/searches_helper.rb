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
    client = record.is_a?(Client) ? nil : Client.find_by(id: record.search_client_id)
    [ record.model_name.human, client&.name ].compact.join(" · ")
  end
end
