module QuickActionsHelper
  # The record the page is about, for quick actions and plugins ("Start on …").
  def current_record
    return @current_record if defined?(@current_record)

    @current_record =
      case controller_path
      when "clients" then Client.find_by(id: params[:id])
      when "engagements" then Engagement.find_by(ref: params[:ref].to_s.upcase) if params[:ref]
      when "scope_items" then ScopeItem.find_by(id: params[:id])
      when "todos" then Todo.find_by(id: params[:id])
      when "requests" then Request.find_by(id: params[:id])
      end
  end

  def record_label(record)
    record.is_a?(ScopeItem) ? record.description : record.search_title
  end

  # Which kind of record it is, in this install's words.
  def record_kind(record)
    record.is_a?(Engagement) ? record.label_name : record_type_term(record.class.name)
  end

  def record_type_term(type)
    case type
    when "Client" then term(:client)
    when "Engagement" then term(:engagement)
    when "ScopeItem" then term(:scope_item)
    when "Todo" then term(:work)
    else type.titleize
    end
  end
end
